# 생활기록부 점검 웹 서비스

## 프로젝트 개요

생활기록부 점검 데스크톱 프로그램(생기부_DB_생성기.exe + 생기부_AI_Inspector.exe)을
웹 서비스로 재구현한 프로젝트. **구현 완료 상태**.

**원본 프로그램 제작:** 대전복수고등학교 박영준 교사  
**기술 스택:** Python FastAPI + SQLite + Google Gemini API + Vanilla JS  
**GitHub:** https://github.com/tigerjk9/school-life-record  
**실행:** `생기부점검_실행.bat` 더블클릭 → `http://127.0.0.1:8000`

## 구현 완료 기능

- NICE XLS 5종 업로드 & SQLite DB 구축 (`생기부점검_실행.bat`)
- 학생 조회 (학년/반/이름/본문 키워드 검색)
- Gemini AI 일괄 점검 (SSE 실시간 스트리밍)
- 결과 확인 및 Excel 내보내기 (4시트)
- 다크/라이트 모드 전환
- 사용 안내 탭 (설치·NICE 파일 받기·탭별 사용법·FAQ)

## 작업 시 참고

- 프론트엔드 3파일: `frontend/index.html`, `frontend/style.css`, `frontend/app.js`
- 백엔드 진입점: `backend/main.py` (FastAPI + StaticFiles mount)
- DB 스키마: `backend/db/schema.sql`
- CSS 캐시 무효화: `style.css?v=3`, `app.js?v=3` (변경 시 버전 번호 올릴 것)
- 테마: `[data-theme="dark"]` 속성을 `<html>`에 설정, `localStorage`로 저장

## 하네스

**목표:** NICE XLS 업로드 → DB 구축 → Gemini AI 점검 → 결과 Excel 내보내기를 웹으로 제공

**트리거:** 추가 기능 개발·버그 수정·디자인 변경 요청 시 `school-record-web` 오케스트레이터 스킬 참고. 단순 질문·소규모 수정은 직접 응답 가능.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-20 | 초기 구성 | 전체 | 하네스 최초 구축 |
| 2026-04-20 | frontend-design 스킬 필수 적용 추가 | frontend 전체 | 디자인 품질 개선 |
| 2026-04-20 | 전체 구현 완료 & GitHub 배포 | 전체 | MVP 완성 |
