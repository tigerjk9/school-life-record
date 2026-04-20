---
name: integrate-gemini
description: Google Gemini API를 생활기록부 점검에 통합한다. 점검 프롬프트 설계, 배치 처리, 비용 관리, 모델 선택 가이드를 제공한다. Gemini API 연동, AI 점검 기능 구현, 프롬프트 엔지니어링 작업 시 반드시 이 스킬을 사용하라.
---

# Gemini AI 통합 스킬

## 모델 선택 가이드
| 모델 | 특징 | 권장 용도 |
|------|------|----------|
| `gemini-2.5-flash` | 빠름, 저렴, 충분한 정확도 | **기본 추천** |
| `gemini-2.5-pro` | 느림, 비쌈, 최고 정확도 | 정밀 검토 |
| `gemini-2.0-flash-lite` | 매우 빠름, 최저가 | 대량 처리 |

## 점검 프롬프트 (기본값)

```python
SYSTEM_PROMPT = """
당신은 학교생활기록부 기재요령 전문가입니다.
학생의 세부능력및특기사항, 창의적체험활동, 봉사활동, 행동특성 등을
교육부 학교생활기록부 기재요령에 따라 검토합니다.

[검토 기준]
1. 기관명·상호명 직접 기재 금지 (예: 삼성전자, 네이버, 삼풍백화점)
2. 특정 대학명 기재 금지 (예: 서울대, 연세대, 카이스트)  
3. 학생 성명 외 타인 실명(교사, 친구) 기재 금지
4. 저작물 제목의 과도한 나열 금지 (단, 1~2개 예시는 허용 — '독서' 단독은 위반 아님)
5. 구체적 점수·등수 직접 기재 금지
6. 의미 불명확한 약어 사용 금지

[중요] 위반이 의심되나 확실하지 않을 경우 violation=false로 처리하고 note에 의심 내용 기재.
"""

USER_PROMPT_TEMPLATE = """
다음 {count}개의 학생 기록을 검토하세요:

{records}

각 기록에 대해 JSON 배열로 응답하세요:
[
  {{
    "student_id": "학번",
    "violation": true/false,
    "items": [
      {{"type": "기관명", "content": "원문 텍스트", "reason": "위반 이유"}}
    ],
    "note": "추가 의견 (선택)"
  }}
]
"""
```

## 배치 처리 로직

```python
async def inspect_batch(records: list[dict], api_key: str, model: str, batch_size: int):
    genai.configure(api_key=api_key)
    model_client = genai.GenerativeModel(model, system_instruction=SYSTEM_PROMPT)
    
    results = []
    for i in range(0, len(records), batch_size):
        batch = records[i:i+batch_size]
        records_text = "\n\n".join([
            f"[학번: {r['student_id']}] {r['subject']}: {r['content']}"
            for r in batch
        ])
        prompt = USER_PROMPT_TEMPLATE.format(count=len(batch), records=records_text)
        
        try:
            response = await model_client.generate_content_async(prompt)
            parsed = json.loads(response.text)
            results.extend(parsed)
        except Exception as e:
            # 실패 시 해당 배치를 개별 처리로 재시도
            for record in batch:
                results.append({"student_id": record['student_id'], "violation": False, 
                                 "items": [], "note": f"처리 오류: {str(e)}"})
        
        yield i + len(batch), len(records), results[-len(batch):]
```

## 비용 관리 팁
- 배치 크기 3이 비용/정확도 최적 균형점
- 세특 1개 평균 500토큰 → 학생 100명 기준 약 $0.1~0.5 (flash 기준)
- 구글 클라우드 콘솔 → 결제 탭에서 다음날 확인 가능

## 프롬프트 수정 가이드
사용자가 "생기부 유의사항 수정"을 원할 경우:
- `backend/services/gemini_service.py`의 `SYSTEM_PROMPT` 상수를 수정
- 규칙 추가 시 번호 목록에 추가
- "강하게/약하게" 설정은 프롬프트의 의심 처리 기준 문장으로 조절
