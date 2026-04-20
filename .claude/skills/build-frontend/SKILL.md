---
name: build-frontend
description: 생활기록부 웹 서비스의 프론트엔드 UI를 구현한다. 파일 업로드, DB 조회, AI 점검, 결과 뷰어 4개 탭으로 구성된 단일 페이지 앱을 vanilla HTML/CSS/JS로 만든다. frontend/ 디렉토리 구현, UI 개발, 화면 작성 작업 시 반드시 이 스킬을 사용하라.
---

# 프론트엔드 구현 스킬

## 디자인 우선 원칙

**구현 전 반드시 `frontend-design` 스킬을 먼저 실행한다.**

`frontend-design` 스킬은 레이아웃, 색상 팔레트, 컴포넌트 스타일, 타이포그래피를 구체적으로
결정하는 디자인 패스다. 이 스킬의 산출물을 바탕으로 CSS와 HTML을 작성해야 시각적으로
완성도 높은 UI가 나온다. 스킬 없이 "적당히" 구현하면 디자인 품질이 저하된다.

**적용 순서:**
1. `frontend-design` 스킬 실행 → 디자인 명세 산출
2. 산출된 디자인 명세를 `_workspace/03_frontend_design.md`에 저장
3. 해당 명세를 따라 `style.css` 작성
4. `index.html` + `app.js` 구현

## 기술 스택
- 순수 HTML5 + CSS3 + JavaScript (ES6+)
- 외부 라이브러리 없음 (CDN 사용 시 명시)
- FastAPI `StaticFiles`로 서빙: `backend/static/` 또는 별도 `frontend/`

## 파일 구조
```
frontend/
├── index.html   # 단일 페이지, 4개 탭 구조
├── style.css    # 깔끔한 한국어 교육 UI
└── app.js       # API 통신, 상태 관리, UI 조작
```

## 4탭 구조

### 탭 1: 파일 업로드
- XLS 5종 각각 업로드 영역 (drag & drop 또는 파일 선택)
- 업로드 순서 안내: "교과성적을 먼저 업로드해야 합니다"
- 각 파일 업로드 상태 표시 (미완료/완료/오류)
- "DB 구축" 버튼 (5종 모두 업로드 시 활성화)

### 탭 2: DB 조회
- 학년/반 선택 드롭다운
- 이름/번호 검색 입력
- 학생 목록 테이블 (학년, 반, 번호, 이름, 기록 여부)
- 행 클릭 → 세특/창체/봉사/행동특성 상세 모달

### 탭 3: AI 점검
- Gemini API 키 입력 (password 타입, 로컬스토리지에 저장 옵션)
- 모델 선택: gemini-2.5-flash (추천) / gemini-2.5-pro / gemini-2.0-flash-lite
- 배치 크기: 1~5 슬라이더 (기본값 3)
- 점검 범위: 세특 / 창체 / 봉사 / 행동특성 체크박스
- "검사 시작" 버튼
- 실시간 진행률 바 + "현재 n / 전체 N" 텍스트
- SSE 연결 상태 표시

### 탭 4: 결과 확인
- 필터 버튼: [전체보기] [위반만] [정상만]
- 결과 테이블: 학생명, 항목, 위반유형, 내용 미리보기
- 행 더블클릭 → 상세 모달 (위반 이유, 원문, AI 설명)
- "Excel 다운로드" 버튼

## 핵심 JS 패턴

### SSE 연결
```javascript
const params = new URLSearchParams({ api_key: apiKey, model, batch });
const es = new EventSource(`/api/inspect/progress?${params}`);
es.onmessage = (e) => {
  const { current, total, results } = JSON.parse(e.data);
  updateProgress(current, total);
  appendResults(results);
};
```

### API 키 로컬스토리지
```javascript
// 저장
localStorage.setItem('gemini_api_key', apiKey);
// 복원
document.getElementById('apiKey').value = localStorage.getItem('gemini_api_key') || '';
```

## UI 스타일 가이드
- 색상: 파란 계열 (#2563eb 주색, 흰 배경)
- 폰트: 시스템 한국어 폰트 (`"Malgun Gothic", sans-serif`)
- 테이블: 줄무늬(striped), hover 강조
- 모달: 반투명 오버레이, 중앙 정렬
- 버튼 상태: disabled 시 회색, loading 시 스피너
