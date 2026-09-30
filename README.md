# AIRC — AI 기록·의미 추적 CLI

[![FreeLang](https://img.shields.io/badge/runtime-FreeLang%20v11-0b756d)](https://github.com/kimjindol2025/freelang-tools)
[![Status](https://img.shields.io/badge/status-active-2ea44f)](./SPEC.airc)
[![Forgejo](https://img.shields.io/badge/source-Forgejo-f78000)](https://fg.dclub.kr/kim/airc-spec)

FreeLang 프로젝트의 결정, 사실, 오류, 의도, 의존성과 인수인계를 **AI가 다시 읽을 수 있는 구조**로 기록하고 조회하는 AIRC 프로젝트다.

```text
기록(.airc / SPEC.airc)
        ↓
구조화된 노드·관계·provenance
        ↓
status / why / deps / search / graph
```

## AIRC는 무엇인가

AIRC는 일반 문서 폴더나 단순 문자열 검색기가 아니다.

- 현재 무엇이 중요한지: `hot`, `next`
- 왜 결정했는지: `decision`, `why`
- 무엇이 검증됐는지: `fact`, `verified`
- 무엇이 실패했는지: `error`, `cause`, `fix`
- 어떤 작업이 막혔는지: `deps`, `blocked_by`
- 다음 작업자에게 무엇을 넘길지: `handoff`

를 정해진 노드 구조로 보존한다.

### 언어 계열 경계

AIRC는 FreeLang v11 계열 runner 위에서 실행되지만, AFJ와 같은 언어는 아니다.

```text
FreeLang v11 — 조상 계열 runner / 언어 기준선
AFJ            — 별도 FreeLang 방언
AIRC           — AI 기록·의미 추적 프로젝트와 CLI
```

각 계열의 문법과 runner를 섞지 않는다. 현재 AIRC 실행 기준선은 저장소의
`FREELANG_V11_RUNNER` 또는 서버의 FreeLang v11 runner다.

## 빠른 시작

### 공통 도구 사용

```bash
cd airc-spec

# 프로젝트와 runner 확인
fl-tools start .

# 전체 .fl 소스 검사
fl-tools check .

# AIRC 상태 조회
fl-tools airc . status
```

### runner 직접 실행

```bash
node /home/kim/kim/platform/freelang-v11-fx/bootstrap.js \
  run airc.fl status
```

다른 환경에서는 runner를 명시한다.

```bash
FREELANG_AIRC_RUNNER=/path/to/bootstrap.js fl-tools airc . status
```

## CLI 명령

```text
airc status              현재 hot 상태와 주요 현황
airc hot                 현재 가장 중요한 노드
airc next                다음 작업
airc lock                잠금 규칙
airc graveyard           재도입하지 않을 항목
airc handoff             다음 작업자 인수인계
airc why <node-id>       노드의 이유와 근거
airc index               타입·태그·상태별 전체 인덱스
airc search <keyword>    노드 전문 검색
airc active              활성 노드 목록
airc dead                무효화·대체된 노드 목록
airc deps <node-id>      needs와 blocks 관계
airc from <node-id>      provenance.from 조회
airc causes <node-id>    provenance.causes 조회
airc graph               의존성과 provenance 텍스트 그래프
airc blockers            FREEDOC blocker 집계
```

공통 관문에서는 다음처럼 실행한다.

```bash
fl-tools airc . status
fl-tools airc . search task
fl-tools airc . why task-004
fl-tools airc . graph
```

## 저장 구조

| 파일 | 역할 |
| --- | --- |
| `SPEC.airc` | AIRC constitution, node type, field rule, hot/lock/graveyard 정본 |
| `airc.fl` | 상태·검색·관계 조회 CLI |
| `GRAMMAR.airc` | AIRC 문법과 실행 계약 |
| `AIRC-SCHEMA.fds` | 스키마 원본 기록 |
| `DESIGN.airc` | 설계 결정과 의미 구조 |
| `TEMPLATE.airc` | 새 AIRC 문서 템플릿 |
| `data/airc-graph.json` | canonical graph |
| `data/full-text-index.json` | 전문 검색 인덱스 |
| `data/reverse-map.json` | 의존성·영향 역인덱스 |
| `fds-to-airc.fl` | FREEDOC.fds → AIRC 변환 도구 |
| `airc-parser-v2.fl` | SPEC와 FREEDOC.airc 통합 parser |

## 노드 원칙

`SPEC.airc`의 constitution이 정본이다.

- 성공만 기록하지 않고 실패와 반복 오류도 기록한다.
- 검증된 사실만 `fact`와 `verified:true`로 기록한다.
- 추측은 `assumption`으로 분리한다.
- 사용자 의도는 원문 `quote`로 보존한다.
- 노드를 삭제하지 않고 lifecycle 상태로 무효화한다.
- `lock`에는 반드시 이유와 출처가 있어야 한다.
- `handoff`는 다음 작업자가 바로 읽을 수 있어야 한다.

## 검증 상태

현재 로컬 기준 검증:

```text
fl-tools start .       PASS
fl-tools check .       PASS
fl-tools airc . status PASS
git diff --check       PASS
```

자동 테스트 디렉터리는 아직 없으므로 `fl-tools test .` 결과는
`FREELANG_TEST=NO_TESTS`로 보고된다. 문법 검사와 실제 AIRC 상태 실행은
FreeLang v11 runner로 확인한다.

## 저장소

- GitHub: https://github.com/kimjindol2025/airc-spec
- Forgejo: https://fg.dclub.kr/kim/airc-spec
- 공통 도구: https://github.com/kimjindol2025/freelang-tools

## 라이선스

현재 라이선스 정책은 저장소 소유자의 프로젝트 운영 기준을 따른다.
