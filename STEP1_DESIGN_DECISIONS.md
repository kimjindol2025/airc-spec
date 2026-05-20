# PM2 Gateway Step 1 — 3가지 설계 결정

**결정 권한**: 사용자 (2026-05-20)  
**구현 담당**: Claude (Phase 1A: 2-3시간)  
**진입 조건**: 3가지 모두 고정됨

---

## 🎯 Decision 1: PM2 Gateway를 "유일한 Mutation 경로"로 강제

### 원칙

```txt
직접 pm2 명령 = 금지
모든 변경 = Gateway API 경유 (POST /pm2/action)
```

### 적용 대상

- ✅ Claude (모든 세션)
- ✅ Shell script (automation)
- ✅ Webhook (automation)
- ✅ Dashboard (UI)
- ✅ CLI (직접 명령)

### 감시 추가

`unexpected pm2 mutation detected` 로그:
- 직접 `pm2 restart/delete/start` 호출 감지
- Gateway 우회 시도 적발
- Audit JSONL에 기록

### 구현

```
pm2-gateway.fl
├─ (server-post "/pm2/action" handle-action)
├─ whitelist adapter (allowed_actions)
├─ atomic O_EXCL lock (TTL 60초)
└─ response ✅ / ❌

감시: inotifywait /proc/sys/kernel/perf_event_paranoid 불가 → shell-exec로 pm2 명령 grep
```

---

## 🎯 Decision 2: Bootstrap Singleton은 프로세스 레벨에서 막기

### 문제

PM2 maxInstances = 4 로는 부족:
- self-spawn (bootstrap이 자신을 fork)
- manual node bootstrap.js
- watcher fork
- 모두 PM2 바깥에서 발생

### 해결책

## /tmp/freelang-bootstrap.lock

```json
{
  "pid": 1234,
  "ppid": 999,
  "startedAt": "2026-05-20T10:30:00Z"
}
```

### 로직

```
bootstrap 시작 시:
1. /tmp/freelang-bootstrap.lock 읽기
2. 이미 있으면: EXIT_ALREADY_RUNNING
3. 없으면: O_EXCL로 atomic create
4. 정상 종료 시 lock 삭제
```

### Parent PID 기록 이유

누가 spawn 했는지 추적 가능:
- ppid=1 → 고아 프로세스 (자동 kill 대상)
- ppid=<claude-pid> → Claude 세션 추적
- ppid=<pm2-daemon> → PM2에서 정상 시작

---

## 🎯 Decision 3: Audit는 2가지 이벤트로 분리

### A. Operator Audit

누가 뭘 했는가?

```json
{
  "type": "operator",
  "action": "restart",
  "service": "akl-payment",
  "session": "claude-x",
  "timestamp": "2026-05-20T10:30:00Z",
  "result": "success | failed"
}
```

### B. System Event

시스템이 뭘 감지했는가?

```json
{
  "type": "system",
  "event": "spawn_limit_hit",
  "service": "bootstrap.js",
  "count": 5,
  "timestamp": "2026-05-20T10:30:00Z"
}
```

또는:

```json
{
  "type": "system",
  "event": "unexpected_restart_loop",
  "service": "akl-notify",
  "restart_count": 47,
  "interval_ms": 1200,
  "timestamp": "2026-05-20T10:30:00Z"
}
```

### 왜 분리하는가

분리 안 하면 운영에서:
- 사용자 액션 vs 자동 복구 구분 불가
- 비정상 증식 vs 정상 동작 구분 불가
- 운영 지옥

---

## 🚫 절대 하면 안 되는 것

### 1. Distributed system 흉내

아직 불필요:
- ❌ Redis lock
- ❌ etcd
- ❌ Kafka
- ✅ 파일 기반 atomic lock만

### 2. Kubernetes 스타일 과설계

아직 단계 아님:
- ❌ scheduler
- ❌ pod orchestration
- ❌ reconciliation loop

필요한 것:
- ✅ 통제 가능한 PM2 runtime

### 3. Auto recovery 추가

아직 금지:
- 원인: restart storm 위험
  ```
  restart 실패
  → auto recover
  → watchdog restart
  → PM2 restart
  → loop
  ```

- 문제:
  - restart storm
  - fork storm
  - audit flood

**결정**: Phase 1B 이후 (spawn detection/orphan detection 완료 후)

---

## ✅ Step 1 성공 기준 (5개)

### 1. 동시 restart 요청

```
2개 Claude가 동시에:
POST /pm2/action {"action":"restart", "service":"akl-payment"}
```

**결과**: 하나만 실행, 다른 하나는 대기 → 선착순 1개 처리

### 2. 100% 추적 가능

```
pm2 logs akl-payment | grep "restarted by"
```

**결과**: `restarted by claude-session-xyz at 2026-05-20T...`

### 3. Bootstrap 폭증 자동 차단

```
node bootstrap.js &
node bootstrap.js &  # 즉시 EXIT_ALREADY_RUNNING
```

### 4. Tier2 아니면 pm2 delete 불가

```
POST /pm2/action {"action":"delete", "service":"akl-payment"}
status: 403 FORBIDDEN

role: tier2
POST /pm2/action {"action":"delete", ...}
status: 200 OK
```

### 5. 여러 Claude 떠 있어도 안정

```
3개 Claude 세션 + automation script
→ 충돌 없음
→ 모든 변경이 audit에 기록됨
→ 운영 상태 안정 유지
```

---

## 📊 Step 1 구현 일정 (2-3시간)

| Phase | 모듈 | 시간 | 입력 | 출력 |
|-------|------|------|------|------|
| 1A-1 | `pm2-gateway.fl` | 45분 | — | POST /pm2/action route |
| 1A-2 | `pm2-lock.fl` | 30분 | action | atomic lock + TTL cleanup |
| 1A-3 | `pm2-audit.fl` | 30분 | action + system event | JSONL append |
| 1A-4 | `pm2-role.fl` | 20분 | session | role-based adapter |
| 1A-5 | `bootstrap-guard.sh` | 15분 | — | /tmp/lock + ppid 추적 |
| **합계** | — | **140분** | — | **5개 모듈 완성** |

---

## 🔒 Lock 항목 (이 3가지 고정됨)

```
Lock 1: PM2 Gateway = 유일한 Mutation 경로
Lock 2: Bootstrap = 프로세스 레벨 singleton  
Lock 3: Audit = Operator + System 분리
```

사용자 협의 없이 변경 불가.

---

**다음**: `pm2-gateway.fl` 구현 시작 (Step 1A-1)
