# 구현 계획 — 생활기록부 점검 웹 서비스

## 파일 구조 (생성할 모든 파일)

```
school-life-record/
├── requirements.txt
├── .env.example
├── backend/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models.py
│   ├── state.py
│   ├── db/
│   │   └── schema.sql
│   ├── services/
│   │   ├── __init__.py
│   │   ├── xls_parser.py
│   │   ├── db_builder.py
│   │   ├── gemini_service.py
│   │   ├── inspector.py
│   │   └── export_service.py
│   └── routers/
│       ├── __init__.py
│       ├── upload.py
│       ├── students.py
│       ├── inspect.py
│       └── export.py
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── app.js
├── data/           (자동 생성)
└── logs/           (자동 생성)
```

## Phase A — 백엔드 (순서 있음)

### A-1. requirements.txt
fastapi, uvicorn[standard], pandas, openpyxl, xlrd==2.0.1, xlsxwriter, google-generativeai, python-dotenv, aiofiles

### A-2. backend/database.py
- get_connection(): WAL + foreign_keys, Row factory
- init_db(): schema.sql DDL 실행 (idempotent)
- backup_db(): record.db.bak.{timestamp} 복사
- transaction() 컨텍스트 매니저

### A-3. backend/models.py
Pydantic DTO: 업로드/DB/학생/점검/결과 요청·응답 모델, SSE 이벤트 페이로드 모델

### A-4. backend/services/xls_parser.py
- detect_engine(path): .xls→xlrd, .xlsx→openpyxl
- read_with_header_autodetect(): 상위 10행 스캔, 후보 컬럼명 첫 매치 행을 헤더로
- normalize_columns(df): 공백/줄바꿈/괄호 제거, 표준 키 매핑
- 5개 파서: parse_subject_grades, parse_subject_details, parse_creative, parse_volunteer, parse_behavior

### A-5. backend/services/db_builder.py
- 교과성적 없으면 ValueError
- backup_db → init_db → 교과성적 upsert → 나머지 4개 INSERT
- BEGIN IMMEDIATE 단일 트랜잭션, executemany 사용

### A-6. backend/services/gemini_service.py
- set_api_key / get_api_key
- connect_and_list_models(): gemini-2.5-* 필터
- inspect_batch() async: response_mime_type=application/json, 재시도 3회(지수 백오프), asyncio.to_thread 래핑

### A-7. backend/services/inspector.py
- start_inspection(): inspections INSERT → asyncio.create_task
- _run_inspection(): 배치 루프 → gemini_service → DB INSERT → 큐 push
- cancel(), event_stream() async generator (SSE 포맷)

### A-8. backend/services/export_service.py
xlsxwriter로 4시트(요약/위반/정상/전체), 위반행 빨간 폰트, 컬럼 폭 자동

### A-9~12. backend/routers/
- upload.py: POST /api/upload, POST /api/db/build, GET /api/db/status
- students.py: GET /api/students, GET /api/students/{id}/details, GET /api/search
- inspect.py: POST /api/gemini/connect, GET|PUT /api/prompt, POST /api/inspect/start, GET /api/inspect/stream/{id} (SSE), POST /api/inspect/cancel/{id}, GET /api/inspections
- export.py: GET /api/results, GET /api/results/export

### A-13. backend/main.py
라우터 등록 → StaticFiles mount(/) 마지막에 → lifespan에서 init_db

## Phase B — 프론트엔드 (A와 병렬)

**선행**: frontend-design 스킬 실행 → 디자인 토큰 결정

### B-1. frontend/index.html — 4탭 단일 페이지
- 탭1 업로드: 5개 드롭존 + DB구축 버튼
- 탭2 조회: 학년/반/이름 필터 + 테이블 + 상세 모달
- 탭3 점검: API키+연결, 모델/배치/영역 설정, 시작/취소, 진행률바, 라이브 결과
- 탭4 결과: 이력 select, 필터 라디오, 테이블, 모달, Excel 다운로드
- hash 라우팅(#upload/#search/#inspect/#results)

### B-2. frontend/style.css
CSS 변수 기반 디자인 토큰, 컴포넌트(탭/드롭존/테이블/뱃지/버튼/모달/진행률바), 1024px+ 데스크톱 최적화

### B-3. frontend/app.js
- api 객체 (14개 엔드포인트 fetch 래퍼)
- EventSource SSE (progress/result/error/done 이벤트)
- 드래그앤드롭, 필터/모달, 에러 토스트

## Phase C — 통합 검증

### C-1. StaticFiles 마운트 순서 확인 (API 라우터 → mount 순)
### C-2. 엔드포인트 경로 프론트-백엔드 일치 매트릭스 (14개)
### C-3. SSE 이벤트 형식 일치 확인 (event:/data: 라인 쌍)

## SSE 이벤트 표준 형식 (프론트-백엔드 계약)

```
event: progress
data: {"processed": 3, "total": 30, "current_student": "1-2-15 홍길동", "current_area": "subject_details"}

event: result
data: {"student_id": 7, "area": "subject_details", "record_id": 42, "violation": true, "category": "기관명 명시", "reason": "...", "evidence": "..."}

event: done
data: {"total_violations": 5, "total_normal": 25, "duration_sec": 312.5}
```

## 위험 요소
1. NICE XLS 실제 컬럼 미확정 → 후보 컬럼 dict + 미매칭 로깅 + 응답에 포함
2. Windows SQLite 잠금 → backup 전 connection 닫기
3. xlrd 2.0+ .xls만 지원 → 엔진 분기 필수
4. Gemini SDK 반환 객체 속성 변동 → hasattr 안전 추출
5. SSE 버퍼링 → X-Accel-Buffering: no 헤더 필수
6. 취소는 asyncio.Event 협조적 종료 (현재 Gemini 호출 끝까지 기다림)
