---
name: school-record-web
description: 생활기록부 점검 웹 서비스 개발을 전체 조율한다. 프로그램 분석 → 아키텍처 설계 → 백엔드/프론트엔드 병렬 구현 → QA의 파이프라인을 실행한다. "생기부 웹서비스 만들어", "구현 시작해줘", "개발해줘", "백엔드 만들어", "프론트 만들어", "다시 실행", "재실행", "이어서 진행", "수정해줘", "보완해줘", "결과 개선" 등의 요청 시 반드시 이 스킬을 사용하라.
---

# 생활기록부 웹 서비스 오케스트레이터

**실행 모드:** 하이브리드
- Phase 1~2: 서브 에이전트 (순차 분석·설계)
- Phase 3: 에이전트 팀 (백엔드 + 프론트엔드 병렬 구현)
- Phase 4: 서브 에이전트 (QA)

## Phase 0: 컨텍스트 확인

`_workspace/` 존재 여부로 실행 모드 결정:
- `_workspace/` 없음 → **초기 실행**: Phase 1부터
- `_workspace/` 있음 + 사용자가 부분 수정 요청 → **부분 재실행**: 해당 Phase만
- `_workspace/` 있음 + 새 요청 → **새 실행**: `_workspace/`를 `_workspace_prev/`로 이동 후 Phase 1부터

## Phase 1: 프로그램 분석 (서브 에이전트)

`analyze-program` 스킬을 활용하는 analyst 에이전트 호출:

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "analyze-program 스킬을 사용하여 생활기록부 점검 프로그램을 분석하라.
           프로젝트 루트의 PPTX 파일을 읽고 _workspace/01_analyst_requirements.md와
           _workspace/01_analyst_xls_schema.md를 생성하라.
           agents/analyst.md의 역할과 원칙을 따르라."
)
```

완료 조건: `_workspace/01_analyst_requirements.md` 존재

## Phase 2: 아키텍처 설계 (서브 에이전트)

architect 에이전트 호출:

```
Agent(
  subagent_type: "Plan",
  model: "opus",
  prompt: "_workspace/01_analyst_*.md를 읽고 웹 서비스 아키텍처를 설계하라.
           _workspace/02_architect_design.md와 _workspace/02_architect_api_spec.md를 생성하라.
           agents/architect.md의 역할과 원칙을 따르라."
)
```

완료 조건: `_workspace/02_architect_api_spec.md` 존재

## Phase 3: 병렬 구현 (에이전트 팀)

backend-engineer + frontend-engineer를 팀으로 구성하여 병렬 실행:

```
TeamCreate(
  team_name: "implementation-team",
  members: ["backend-engineer", "frontend-engineer"]
)

TaskCreate([
  {
    id: "backend",
    title: "백엔드 구현",
    description: "build-backend 스킬을 사용하여 backend/ 디렉토리를 구현하라.
                  agents/backend-engineer.md + skills/build-backend/SKILL.md + skills/integrate-gemini/SKILL.md 참조.
                  완료 시 qa-engineer에게 SendMessage 알림.",
    agent: "backend-engineer"
  },
  {
    id: "frontend",
    title: "프론트엔드 구현",
    description: "다음 순서를 반드시 지켜 구현하라:
                  1) frontend-design 스킬을 먼저 실행하여 디자인 명세를 수립하고 _workspace/03_frontend_design.md에 저장
                  2) build-frontend 스킬을 사용하여 frontend/ 디렉토리를 구현 (디자인 명세 반드시 적용)
                  agents/frontend-engineer.md + skills/build-frontend/SKILL.md 참조.
                  완료 시 qa-engineer에게 SendMessage 알림.",
    agent: "frontend-engineer"
  }
])
```

완료 조건: `backend/main.py`, `frontend/index.html` 존재

## Phase 4: QA (서브 에이전트)

qa-engineer 에이전트 호출:

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "agents/qa-engineer.md의 검증 체크리스트를 모두 수행하라.
           backend/ + frontend/ + _workspace/02_architect_api_spec.md를 교차 비교하여
           경계면 버그를 찾고 _workspace/05_qa_report.md에 리포트를 작성하라.
           버그가 있으면 해당 파일을 직접 수정하라."
)
```

완료 조건: `_workspace/05_qa_report.md` 존재

## Phase 5: 최종 정리

1. `README.md` 생성 (실행 방법, 의존성 설치, 사용 방법)
2. 사용자에게 결과 요약 보고:
   - 구현된 파일 목록
   - 실행 명령어
   - QA 결과 요약
3. 피드백 요청: "개선하고 싶은 부분이 있으신가요?"

## 데이터 전달

```
_workspace/
├── 01_analyst_requirements.md   (analyst → architect)
├── 01_analyst_xls_schema.md     (analyst → backend-engineer)
├── 02_architect_design.md       (architect → 모두)
├── 02_architect_api_spec.md     (architect → backend, frontend, qa)
├── 03_frontend_design.md        (frontend-design 스킬 → frontend-engineer)
└── 05_qa_report.md              (qa-engineer 산출)
```

## 에러 핸들링

- Phase 실패 시 1회 재시도
- 재실패 시 해당 Phase 결과 없이 진행, 최종 보고에 누락 명시
- Gemini API 오류: 스킵 후 해당 항목에 오류 표시

## 부분 재실행 가이드

| 사용자 요청 | 재실행 Phase |
|-----------|------------|
| "백엔드 수정해줘" | Phase 3 (backend만) → Phase 4 |
| "프론트 다시 만들어" | Phase 3 (frontend만) → Phase 4 |
| "API 설계 바꿔" | Phase 2 → Phase 3 → Phase 4 |
| "QA 다시 해줘" | Phase 4만 |

## 테스트 시나리오

**정상 흐름:**
1. "생기부 웹서비스 개발 시작해줘" → Phase 0~5 전체 실행
2. `backend/main.py` + `frontend/index.html` 생성 확인
3. QA 리포트에 버그 0개 확인

**부분 재실행:**
1. "백엔드 API 경로 `/api/upload` → `/api/files/upload`로 바꿔줘"
2. Phase 3 backend만 재실행 → Phase 4 QA 실행
3. 변경된 경로가 프론트엔드에도 반영됐는지 QA 확인
