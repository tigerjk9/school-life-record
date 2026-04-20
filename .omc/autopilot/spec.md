# 생활기록부 점검 웹 서비스 스펙

> 원본 데스크톱 프로그램(생기부_DB_생성기.exe + 생기부_AI_Inspector.exe)을 웹 서비스로 래핑한 단일 사용자(single-user) 로컬 웹 애플리케이션 기술 스펙.
> 작성일: 2026-04-20 / 대상: MVP

---

## 기술 스택

| 영역 | 기술 | 비고 |
|---|---|---|
| 언어/런타임 | Python 3.11+ | 타입힌트 적극 사용 |
| 웹 프레임워크 | FastAPI | async 지원, OpenAPI 자동 문서화 |
| ASGI 서버 | uvicorn | `uvicorn app.main:app --reload` |
| DB | SQLite (`./data/record.db`) | 단일 파일, WAL 모드 |
| ORM/쿼리 | sqlite3 (표준 라이브러리) + 직접 SQL | MVP는 ORM 없이 단순화. 필요 시 SQLModel로 확장 |
| AI | Google Gemini API (`google-generativeai` SDK) | 모델: gemini-2.5-pro / gemini-2.5-flash / gemini-2.5-flash-lite |
| Frontend | Vanilla HTML / CSS / JavaScript | 프레임워크 없음. ES2020+ 모듈 |
| XLS 파싱 | pandas + openpyxl | `.xls`는 xlrd, `.xlsx`는 openpyxl로 분기 처리 |
| Excel 출력 | xlsxwriter | 위반/정상 분리 시트 지원 |
| 실시간 진행률 | SSE (Server-Sent Events) | `text/event-stream` 응답 |
| 환경변수 | python-dotenv | `.env` 파일 |
| 로깅 | logging 표준 라이브러리 + RotatingFileHandler | `./logs/app.log` |
| 테스트 | pytest + httpx (TestClient) | API 단위 + 통합 테스트 |

---

## 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│ Browser (Vanilla JS SPA-like)                                   │
│  - index.html  : 업로드/DB 구축                                 │
│  - search.html : 학생 조회                                      │
│  - inspect.html: AI 점검 (SSE 수신)                             │
│  - prompt.html : 시스템 프롬프트 편집                           │
└────────────┬────────────────────────────────────────────────────┘
             │ HTTP/JSON, multipart/form-data, SSE
┌────────────▼────────────────────────────────────────────────────┐
│ FastAPI App (uvicorn)                                           │
│  ├─ routers/                                                    │
│  │   ├─ upload.py    POST /api/upload                          │
│  │   ├─ db.py        POST /api/db/build, GET /api/db/status    │
│  │   ├─ students.py  GET  /api/students, /api/students/{id}    │
│  │   ├─ inspect.py   POST /api/inspect/start (SSE), /cancel    │
│  │   ├─ results.py   GET  /api/results, /api/results/export    │
│  │   └─ prompt.py    GET/PUT /api/prompt                       │
│  ├─ services/                                                   │
│  │   ├─ xls_parser.py   (NICE XLS 5종 파싱)                   │
│  │   ├─ db_builder.py   (SQLite 스키마/INSERT)                │
│  │   ├─ gemini_client.py (Gemini SDK 래퍼, 배치 처리)         │
│  │   ├─ inspector.py    (점검 오케스트레이션 + 큐)            │
│  │   └─ excel_writer.py (xlsxwriter)                          │
│  └─ db/                                                         │
│      └─ schema.sql                                              │
└────────────┬────────────────────────────────────────────────────┘
             │
   ┌─────────▼──────────┐         ┌──────────────────────┐
   │ SQLite record.db   │         │ Google Gemini API    │
   │ (./data/record.db) │         │ (외부 HTTPS)         │
   └────────────────────┘         └──────────────────────┘
```

### 주요 결정 사항
- **단일 프로세스, 단일 SQLite 파일**: 멀티 사용자 가정 없음. 동시성은 SQLite WAL 모드와 `BEGIN IMMEDIATE`로 처리.
- **SSE만 사용 (WebSocket 미사용)**: 진행률은 단방향 push로 충분.
- **백그라운드 작업은 asyncio Task**: Celery/RQ 등 외부 워커 도입하지 않음.
- **Gemini 호출은 배치 단위로 직렬 처리**: 동시 호출은 비용/할당량 제어 어려움. `asyncio.gather`는 사용하되 1회 점검당 1배치씩 진행.

---

## 기능 명세

### 파일 업로드

**대상 파일**: NICE 학생부 항목별 조회로 내려받은 XLS 5종
1. 교과학습발달상황 (교과성적) — **DB 구축 시 1순위 필수**
2. 세부능력및특기사항 (세특)
3. 창의적체험활동 (창체)
4. 봉사활동상황
5. 행동특성및종합의견

**플로우**:
1. 사용자가 `/` 페이지에서 5개 파일 슬롯 각각에 드래그앤드롭 또는 파일 선택.
2. 클라이언트는 파일을 `multipart/form-data`로 `POST /api/upload`에 전송.
3. 서버는 `./data/uploads/{uuid}_{원본파일명}`에 저장하고 파일 메타를 응답.
4. 5개 파일 모두 업로드되거나 일부만 업로드된 상태에서 "DB 구축" 버튼 활성화.
   (단, 교과성적은 필수. 미업로드 시 빨간 경고)

**검증 규칙**:
- 확장자: `.xls`, `.xlsx`만 허용
- 파일 크기: 50MB 이하 (NICE 평균 1~5MB 가정)
- MIME 타입: `application/vnd.ms-excel` 또는 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`

**에러 처리**:
- 파일 형식 불일치 → 400 + 에러 메시지 ("XLS/XLSX 파일만 업로드 가능합니다")
- 크기 초과 → 413
- 디스크 쓰기 실패 → 500 + 로그 기록

---

### DB 구축

**플로우**:
1. 사용자가 "DB 구축" 클릭 → `POST /api/db/build` (body: `{file_ids: [...]}` 또는 5개 슬롯 식별자).
2. 서버는 다음 순서로 처리:
   a. 기존 `record.db` 백업 (`record.db.bak.{timestamp}`) 후 신규 생성 또는 덮어쓰기.
   b. **교과성적 먼저 파싱**하여 `students` 테이블에 학생 마스터 INSERT.
      - 학년/반/번호/성명을 키로 `students.id` (자동증가) 부여.
   c. 세특/창체/봉사/행특을 순서 무관하게 파싱하여 각 테이블에 학생ID FK로 INSERT.
3. 파싱 진행률은 SSE 또는 짧은 폴링(`GET /api/db/status`)으로 표시.
4. 완료 시 학생 수, 각 영역 레코드 수 통계 응답.

**파싱 전략 (xls_parser.py)**:
- pandas `read_excel`로 우선 읽고 헤더 행을 자동 탐지(컬럼명 후보 리스트와 매칭).
- 컬럼명 정규화: 공백/줄바꿈 제거, 표준 키로 매핑.
- 미매칭 컬럼은 경고 로그 + 무시.
- 학생 식별: `(학년, 반, 번호, 성명)` 튜플을 키로 사용 (학번 컬럼이 있으면 우선 사용).

**오류 시**:
- 교과성적 파일이 없으면 400 + "교과성적 XLS를 먼저 업로드해야 합니다".
- 파싱 중 컬럼 누락 → 부분 성공 처리 + 누락 항목 응답.

---

### 학생 조회

**페이지**: `/search.html`

**필터 UI**:
- 학년 select (1/2/3/전체)
- 반 select (학년 선택 시 동적 로드)
- 번호 input
- 이름 input (부분 일치)
- 영역 탭 (교과성적 / 세특 / 창체 / 봉사 / 행특)
- 본문/과목명 검색 input (LIKE 검색)

**API 흐름**:
- `GET /api/students?grade=3&class_no=2` → 학생 목록 (id, 학년, 반, 번호, 성명, 각 영역 작성여부)
- `GET /api/students/{id}/details?area=subject_details` → 해당 학생의 해당 영역 상세 레코드
- `GET /api/search?keyword=환경&area=subject_details` → 본문/과목명 LIKE 검색

**UI 동작**:
- 학생 목록은 테이블로 표시. 각 영역 컬럼은 "작성됨/미작성" 뱃지.
- "작성됨" 클릭 → 모달로 본문 표시 (텍스트는 읽기 전용 textarea + 복사 버튼).

---

### AI 점검

**페이지**: `/inspect.html`

**설정 영역**:
- API 키 입력 (`<input type="password">`) + "연결 & 모델 로드" 버튼
  - 클릭 시 `POST /api/gemini/connect`로 키 검증, 모델 목록 응답.
  - 키는 서버 메모리(또는 `.env`로 영구 저장 옵션) 보관. 클라이언트 저장 금지.
- 모델 select (gemini-2.5-pro / gemini-2.5-flash / gemini-2.5-flash-lite)
- 배치 크기 number input (1~5, 기본 3)
- 점검 대상 선택:
  - 학년 전체 / 반 전체 / 개별 학생 다중 선택 (체크박스 트리)
- 점검 영역 체크박스: 세특 / 창체 / 봉사 / 행특 (교과성적 본문이 없으므로 제외)
- "검사 시작" / "검사 취소" 버튼
- 시스템 프롬프트 미리보기 + "수정" 링크 → `/prompt.html`

**플로우**:
1. "검사 시작" 클릭 → `POST /api/inspect/start` (body: 대상/영역/모델/배치크기)
2. 서버는 `inspection_id`를 응답하고 백그라운드 asyncio Task로 점검 시작.
3. 클라이언트는 즉시 `EventSource('/api/inspect/stream/{inspection_id}')`로 SSE 연결.
4. 서버는 배치마다 다음 이벤트를 push:
   - `progress`: `{processed, total, current_student, current_area}`
   - `result`: `{student_id, area, record_id, violation: bool, reason, evidence, raw_text}`
   - `error`: `{message}` (배치 실패 시)
   - `done`: `{total_violations, total_normal, duration_sec}`
5. 클라이언트는 `result` 수신 시 결과 테이블에 행 추가, `progress`로 프로그레스바 갱신.
6. "검사 취소" → `POST /api/inspect/cancel/{inspection_id}` → asyncio Task에 취소 신호.

**Gemini 호출 (gemini_client.py)**:
- 시스템 프롬프트 + 배치 크기만큼의 본문을 user 메시지로 전송.
- 응답은 JSON 형식 강제 (`response_mime_type="application/json"`).
- 응답 스키마(예시):
  ```json
  {
    "results": [
      {
        "record_id": 123,
        "violation": true,
        "category": "기관명 명시",
        "reason": "삼풍백화점이라는 특정 기관명 언급",
        "evidence": "...삼풍백화점 사고를..."
      }
    ]
  }
  ```
- 재시도: 429/5xx는 지수 백오프 3회.
- 비용 추정: 호출당 입력/출력 토큰 로깅.

---

### 결과 확인 및 내보내기

**결과 테이블 (inspect.html 하단)**:
- 컬럼: 학년, 반, 번호, 성명, 영역, 과목/세부영역, 위반여부, 카테고리, 사유 요약
- 보기 필터 라디오: 전체 / 위반만 / 정상만
- 행 클릭 → 모달로 상세 (원문 + 위반 사유 + 근거 발췌)

**Excel 다운로드**:
- "Excel 다운로드" 버튼 → `GET /api/results/export?inspection_id=...&filter=all`
- xlsxwriter로 다음 시트 구성:
  - `요약`: 점검 일시, 모델, 배치, 총건수, 위반건수, 정상건수
  - `위반`: 위반 레코드만 (학년/반/번호/성명/영역/원문/카테고리/사유/근거)
  - `정상`: 정상 레코드만
  - `전체`: 모든 레코드
- 파일명: `생기부점검결과_{YYYYMMDD_HHMMSS}.xlsx`

**결과 재조회**:
- `GET /api/results?inspection_id=...` → 페이지 진입 시 이전 검사 결과 로드 가능.
- 검사 이력 목록: `GET /api/inspections` → dropdown으로 선택 가능.

---

## API 엔드포인트 목록

| 메서드 | 경로 | 설명 | 요청 본문 | 응답 |
|---|---|---|---|---|
| GET | `/` | 메인 페이지 (업로드 UI) | - | HTML |
| GET | `/search.html` | 학생 조회 페이지 | - | HTML |
| GET | `/inspect.html` | AI 점검 페이지 | - | HTML |
| GET | `/prompt.html` | 시스템 프롬프트 편집 | - | HTML |
| POST | `/api/upload` | XLS 파일 업로드 | multipart (file, area) | `{file_id, area, filename, size}` |
| POST | `/api/db/build` | DB 구축 실행 | `{file_ids: [...]}` | `{status, students, records_per_area}` |
| GET | `/api/db/status` | DB 구축 상태 조회 | - | `{built: bool, last_built_at, stats}` |
| GET | `/api/students` | 학생 목록 | query: grade, class_no, name | `[{id, grade, class_no, number, name, areas: {...}}]` |
| GET | `/api/students/{id}/details` | 학생 영역별 상세 | query: area | `{records: [...]}` |
| GET | `/api/search` | 본문 검색 | query: keyword, area | `[{record_id, student, snippet}]` |
| POST | `/api/gemini/connect` | API 키 검증 + 모델 목록 | `{api_key}` | `{ok, models: [...]}` |
| GET | `/api/prompt` | 시스템 프롬프트 조회 | - | `{prompt: "..."}` |
| PUT | `/api/prompt` | 시스템 프롬프트 저장 | `{prompt}` | `{ok}` |
| POST | `/api/inspect/start` | 점검 시작 | `{targets, areas, model, batch_size}` | `{inspection_id}` |
| GET | `/api/inspect/stream/{id}` | 진행률 SSE | - | text/event-stream |
| POST | `/api/inspect/cancel/{id}` | 점검 취소 | - | `{ok}` |
| GET | `/api/inspections` | 점검 이력 목록 | - | `[{id, started_at, model, total, violations}]` |
| GET | `/api/results` | 점검 결과 조회 | query: inspection_id, filter | `[{result}]` |
| GET | `/api/results/export` | Excel 다운로드 | query: inspection_id, filter | `application/vnd.openxmlformats-...` |

---

## 데이터베이스 스키마

`./data/record.db` (SQLite, WAL 모드)

```sql
-- 학생 마스터 (교과성적 업로드 시 생성)
CREATE TABLE students (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    grade       INTEGER NOT NULL,
    class_no    INTEGER NOT NULL,
    number      INTEGER NOT NULL,
    name        TEXT    NOT NULL,
    student_id  TEXT,                -- 학번 (있을 경우)
    UNIQUE(grade, class_no, number, name)
);
CREATE INDEX idx_students_grade_class ON students(grade, class_no);

-- 교과성적
CREATE TABLE subject_grades (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    semester    INTEGER,             -- 1/2
    curriculum  TEXT,                -- 교과
    subject     TEXT,                -- 과목
    units       INTEGER,             -- 단위수
    raw_score   REAL,                -- 원점수
    avg_score   REAL,                -- 과목평균
    std_dev     REAL,                -- 표준편차
    achievement TEXT,                -- 성취도 (A~E)
    enrollees   INTEGER,             -- 수강자수
    rank_grade  TEXT                 -- 석차등급
);
CREATE INDEX idx_grades_student ON subject_grades(student_id);

-- 세부능력및특기사항 (세특)
CREATE TABLE subject_details (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    semester    INTEGER,
    curriculum  TEXT,
    subject     TEXT,
    content     TEXT NOT NULL        -- 본문 (점검 대상)
);
CREATE INDEX idx_details_student ON subject_details(student_id);

-- 창의적체험활동 (창체)
CREATE TABLE creative_activities (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    area        TEXT,                -- 자율/동아리/진로
    hours       INTEGER,
    content     TEXT NOT NULL        -- 특기사항 본문
);
CREATE INDEX idx_creative_student ON creative_activities(student_id);

-- 봉사활동상황
CREATE TABLE volunteer_activities (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    period      TEXT,                -- 일자/기간
    place       TEXT,                -- 장소/주관기관
    activity    TEXT,                -- 활동내용
    hours       INTEGER,             -- 시간
    cumulative_hours INTEGER         -- 누계시간
);
CREATE INDEX idx_volunteer_student ON volunteer_activities(student_id);

-- 행동특성및종합의견 (행특)
CREATE TABLE behavior_opinion (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    grade_year  INTEGER,             -- 작성 학년
    content     TEXT NOT NULL
);
CREATE INDEX idx_behavior_student ON behavior_opinion(student_id);

-- 시스템 프롬프트 (단일 행, 사용자 편집 가능)
CREATE TABLE system_prompt (
    id          INTEGER PRIMARY KEY CHECK (id = 1),
    content     TEXT NOT NULL,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 점검 세션
CREATE TABLE inspections (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at  TEXT NOT NULL DEFAULT (datetime('now')),
    finished_at TEXT,
    model       TEXT NOT NULL,
    batch_size  INTEGER NOT NULL,
    target_desc TEXT,                -- "3학년 2반" 등
    status      TEXT NOT NULL,       -- running/done/cancelled/error
    total       INTEGER DEFAULT 0,
    violations  INTEGER DEFAULT 0
);

-- 점검 결과 레코드
CREATE TABLE inspection_results (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id   INTEGER NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
    student_id      INTEGER NOT NULL REFERENCES students(id),
    area            TEXT NOT NULL,   -- subject_details/creative/volunteer/behavior
    record_id       INTEGER NOT NULL,-- 원본 영역 테이블의 id
    violation       INTEGER NOT NULL,-- 0/1
    category        TEXT,            -- 위반 유형 (기관명/특정상품 등)
    reason          TEXT,            -- AI 사유
    evidence        TEXT,            -- 본문 발췌
    raw_response    TEXT,            -- Gemini 원본 응답 (디버그)
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_results_inspection ON inspection_results(inspection_id);
CREATE INDEX idx_results_violation ON inspection_results(inspection_id, violation);
```

---

## 비기능 요구사항

### 성능
- 한 반(약 30명) 세특 일괄 점검: **10분 이내** 완료 (gemini-2.5-flash, batch=3 기준 가정 — 실측 검증 필요)
- 학생 조회 응답: **200ms 이내** (인덱스 활용)
- DB 구축: 5개 파일 합쳐 1MB 미만일 때 **30초 이내**

### 보안
- API 키는 서버 메모리 또는 `.env` 파일로 보관. 응답 JSON에 절대 포함 금지.
- API 키 입력 input은 `type="password"`.
- CORS는 기본 disable (단일 사용자 로컬 가정). 필요 시 `allow_origins=["http://localhost:8000"]`만 허용.
- 업로드 파일은 확장자/MIME 검증 후 UUID 파일명으로 저장 (경로 traversal 방지).
- SQLite 쿼리는 모두 parameterized. 문자열 concat 금지.

### 신뢰성
- DB 구축 시작 전 자동 백업 (`record.db.bak.{timestamp}`).
- 점검 중 서버 재시작 시 진행 중 inspection은 `status='error'`로 표시.
- Gemini 호출 실패 시 재시도 3회 (지수 백오프 1s/2s/4s), 최종 실패 시 결과에 `violation=null`로 기록하고 다음으로 진행.

### 가용성
- 단일 프로세스 uvicorn 운영. 헬스체크 엔드포인트 `GET /healthz` → `{ok: true}`.
- 로그는 `./logs/app.log`에 일별 로테이트, 14일 보관.

### 사용성
- 모든 페이지 한국어 UI.
- 위반 결과는 빨간색, 정상은 회색 뱃지로 시각적 구분.
- SSE 연결 끊김 시 5초 간격 자동 재연결, 마지막 `Last-Event-ID`로 이어서 수신.

### 호환성
- Python 3.11+ (3.12 권장)
- Windows 10/11, macOS 13+, Ubuntu 22.04+ 모두 동작
- Browser: Chrome/Edge 최신 2개 버전, Firefox 최신.

### 배포
- 로컬 실행: `python -m uvicorn app.main:app --host 127.0.0.1 --port 8000`
- 의존성: `requirements.txt` (fastapi, uvicorn[standard], pandas, openpyxl, xlsxwriter, google-generativeai, python-dotenv, pydantic)
- 정적 파일은 FastAPI `StaticFiles`로 `/static` 마운트.
