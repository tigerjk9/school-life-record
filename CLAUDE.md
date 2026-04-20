# 생활기록부 점검 웹 서비스

## 프로젝트 개요
생활기록부 점검 데스크톱 프로그램(생기부_DB_생성기.exe + 생기부_AI_Inspector.exe)을
웹 서비스로 래핑한 프로젝트.

**원본 프로그램:** 대전복수고등학교 박영준 교사 제작  
**기술 스택:** Python FastAPI + SQLite + Google Gemini API + HTML/JS

## 하네스: 생활기록부 웹 서비스

**목표:** NICE XLS 업로드 → DB 구축 → Gemini AI 점검 → 결과 Excel 내보내기를 웹으로 제공

**트리거:** 생기부/생활기록부 웹서비스 개발, 백엔드/프론트엔드 구현, AI 점검 기능, 재실행/수정 요청 시 `school-record-web` 오케스트레이터 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-20 | 초기 구성 | 전체 | 하네스 최초 구축 |
| 2026-04-20 | frontend-design 스킬 필수 적용 추가 | frontend-engineer.md, build-frontend, school-record-web | 디자인 품질 개선 요청 |
