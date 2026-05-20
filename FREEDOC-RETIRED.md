# FreeDoc 폐기 (2026-05-20)

FREEDOC.fds 포맷은 **더 이상 사용하지 않습니다.** 모든 새 프로젝트는 `SPEC.airc`를 사용합니다.

## 왜 폐기했나

FREEDOC은 **문서** 였지만, AI 에이전트에게 필요한 건 **상태 그래프** 였습니다.

| 구분 | FREEDOC.fds | SPEC.airc |
|---|---|---|
| 목적 | "이게 뭔지" 설명 | "지금 뭘 해야 하는지" 지시 |
| AI가 읽으면 | 맥락은 알지만 다음 행동 모름 | `hot` → `graveyard` 체크 → 실행 |
| 인과 추적 | 없음 | `provenance`·`graveyard` |
| 핸드오프 | 없음 | `handoff.step1~5` |
| 범위 경계 | 없음 | `identity.not` |

핵심: **`identity.not` 필드가 AI의 범위 이탈을 막아줍니다.** FREEDOC에는 이게 없었습니다.

## 마이그레이션

### 새 프로젝트
```bash
cp /root/airc/TEMPLATE.airc <project>/SPEC.airc
# identity 4개 필드 채우기 → 끝
```

### 기존 FREEDOC.fds 프로젝트
- **그대로 두기** 권장. 굳이 변환할 필요 없음.
- 새로 작업할 때 `SPEC.airc` 하나만 만들어서 사용.
- 두 파일 동시 유지 금지 (둘 다 방치됨).

## SPEC.airc 최소 구조

```json
{
  "$": "airc-spec",
  "identity": {
    "what": "...",
    "why":  "...",
    "for":  "...",
    "not":  "..."   ← 가장 중요
  },
  "hot": "task-001",
  "nodes": {
    "task-001": {
      "t": "task",
      "v": "지금 할 일",
      "verified": false,
      "next": ["task-002"]
    }
  },
  "graveyard": [],
  "handoff": { "step1": "...", ... }
}
```

## 폐기된 도구

- `/root/kim/freedoc/` (v1) — 보존하되 새 작업에 사용 금지
- `/root/kim/freedoc-v2/` (v2) — 보존하되 새 작업에 사용 금지
- `freedoc validate` 명령 — 더 이상 호출하지 않음

## 보존 이유

기존 프로젝트가 다수 FREEDOC.fds 의존 중이라 도구 자체는 남깁니다. 단지 **새로 만들지 않을 뿐**.
