# 생활기록부 점검 웹서비스

NICE에서 내보낸 학생부 XLS 파일을 업로드하면 Google Gemini AI가 세특·창체·봉사·행특의 **기재요령 위반 여부를 자동 점검**하는 로컬 웹 도구입니다.

> 원본 프로그램 제작: 대전복수고등학교 박영준 교사

---

## 설치 (최초 1회)

**사전 준비**: Python 3.11 이상, Git

```bash
# 1. 저장소 클론
git clone https://github.com/Dot-Connector/school-life-record.git
cd school-life-record

# 2. 가상환경 생성
python -m venv .venv

# 3. 패키지 설치
.venv\Scripts\activate
pip install -r requirements.txt
```

---

## 실행

설치 완료 후부터는 **`생기부점검_실행.bat`** 더블클릭만으로 시작됩니다.

- 가상환경 자동 활성화 → 서버 시작(포트 8000) → 브라우저 자동 오픈
- 브라우저가 열리지 않으면 직접 `http://127.0.0.1:8000` 접속
- 종료: bat 창 닫기

> ⚠️ 학생 개인정보 보호를 위해 서버는 `127.0.0.1`(내 컴퓨터 전용)로만 실행됩니다.

---

## 사용 흐름

```
NICE XLS 5종 다운로드 → ① 업로드 & DB 구축 → ③ AI 점검 → ④ 결과 Excel 저장
```

### NICE에서 파일 받기

NICE → 학교생활기록부 → **학생부 항목별 조회(출력)** 메뉴에서 아래 5종을 엑셀로 내보냅니다.

| 순서 | 항목 | 비고 |
|------|------|------|
| ① **필수** | 교과학습발달상황 | 반드시 먼저 업로드 |
| ② | 세부능력및특기사항 | AI 점검 대상 |
| ③ | 창의적체험활동상황 | AI 점검 대상 |
| ④ | 봉사활동상황 | AI 점검 대상 |
| ⑤ | 행동특성및종합의견 | AI 점검 대상 |

### 탭별 기능

| 탭 | 기능 |
|----|------|
| ① 업로드 | XLS 업로드 후 DB 구축 |
| ② 학생 조회 | 학년/반/이름/키워드 검색, 기록 상세 확인 |
| ③ AI 점검 | Gemini API 연결 → 일괄 점검 → 라이브 결과 |
| ④ 결과 확인 | 위반 이력 조회, Excel 다운로드 |
| 사용 안내 | 설치·설정·사용법 전체 가이드 (앱 내) |

### Gemini API 키 발급

1. [Google AI Studio](https://aistudio.google.com/) 접속 → 구글 계정 로그인
2. **Get API key** → **Create API key** 클릭
3. `AIza...` 형태의 키 복사 → AI 점검 탭에 입력

무료 티어에서 **Gemini 2.5 Flash** 사용 가능. 학급 규모 점검은 무료 한도 내에서 충분합니다.

---

## 기술 스택

| 구분 | 내용 |
|------|------|
| 백엔드 | Python 3.11, FastAPI, Uvicorn, SQLite |
| AI | Google Gemini API (google-generativeai) |
| 파일 처리 | Pandas, openpyxl, xlrd, xlsxwriter |
| 프론트엔드 | Vanilla JS, CSS Custom Properties (다크/라이트 모드) |

---

## 주의사항

- Gemini API 키는 서버 메모리에만 임시 보관되며 DB·파일에 저장되지 않습니다
- 학생 데이터는 `data/record.db`에 저장됩니다. 파일 관리에 주의하세요
- DB 구축 시 기존 데이터는 `data/record.db.bak.{날짜}`로 자동 백업됩니다
- AI 결과는 **참고용**입니다. 교사가 원문과 함께 최종 판단하세요
- 브라우저는 Chrome/Edge 권장 (SSE 실시간 스트리밍 지원)
