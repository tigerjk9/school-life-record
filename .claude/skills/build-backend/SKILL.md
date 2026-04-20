---
name: build-backend
description: 생활기록부 웹 서비스의 FastAPI 백엔드를 구현한다. XLS 파싱, SQLite DB 구축, Gemini AI 점검 API, SSE 실시간 진행률, Excel 결과 내보내기를 포함한다. backend/ 디렉토리 구현, API 서버 코드 작성, 백엔드 개발 작업 시 반드시 이 스킬을 사용하라.
---

# 백엔드 구현 스킬

## 기술 스택
- **Python 3.11+** + **FastAPI** + **uvicorn**
- **pandas** + **openpyxl**: XLS 파싱
- **google-generativeai**: Gemini API
- **aiofiles**: 비동기 파일 처리
- **xlsxwriter**: 결과 Excel 생성

## 디렉토리 구조
```
backend/
├── main.py              # FastAPI app, CORS, 라우터 등록
├── models.py            # SQLAlchemy 모델 또는 dataclass
├── database.py          # SQLite 연결, 테이블 생성
├── requirements.txt
└── routers/
    ├── upload.py        # XLS 업로드 API
    ├── students.py      # 학생 조회 API
    ├── inspect.py       # AI 점검 API (SSE 포함)
    └── export.py        # Excel 다운로드 API
```

## 핵심 구현 패턴

### XLS 업로드 처리
```python
@router.post("/api/upload/{file_type}")
async def upload_xls(file_type: str, file: UploadFile):
    # file_type: "score" | "seteuk" | "changche" | "bongsa" | "haengdong"
    # pandas로 읽어 중간 파일 저장
    df = pd.read_excel(await file.read(), engine='openpyxl')
    # 컬럼 매핑 후 _workspace/uploads/ 저장
```

### Gemini AI 점검 (SSE)
```python
@router.get("/api/inspect/progress")
async def inspect_progress(request: Request, api_key: str, model: str, batch: int):
    async def event_generator():
        for i, batch_items in enumerate(batches):
            result = await gemini_inspect(batch_items, api_key, model)
            yield f"data: {json.dumps({'current': i+1, 'total': total, 'results': result})}\n\n"
    return StreamingResponse(event_generator(), media_type="text/event-stream")
```

### Gemini 점검 프롬프트 구조
```
[대전제] 당신은 학교생활기록부 기재 전문가입니다.
[목표] 아래 세특/창체/봉사/행동특성 내용의 기재요령 위반 여부를 검토하세요.
[검토 기준]
- 기관명/상호명 직접 기재 금지 (예: 삼성전자, 삼풍백화점)
- 특정 대학명 기재 금지
- 학생 성명 외 타인 실명 기재 금지
- 불명확한 약어/줄임말 사용 금지
[출력 형식] JSON: {"violation": bool, "items": [{"type": "기관명", "content": "원문", "reason": "설명"}]}
```

## CORS 설정
개발 환경: `allow_origins=["*"]`  
프로덕션: 프론트엔드 호스트만 허용

## 에러 응답 형식
```json
{"detail": "오류 메시지 (한국어)"}
```

## 실행 명령
```bash
cd backend && pip install -r requirements.txt && uvicorn main:app --reload --port 8000
```
