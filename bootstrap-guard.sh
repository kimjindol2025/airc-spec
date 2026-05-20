#!/bin/bash
# Bootstrap Guard v1.0
# Process-level singleton for freelang-bootstrap.js
#
# Prevents multiple bootstrap processes from running simultaneously
# Records parent PID for orphan process detection

set -e

BOOTSTRAP_BIN="${BOOTSTRAP_BIN:-/home/kimjin/freelang-v11/bootstrap.js}"
LOCK_FILE="/tmp/freelang-bootstrap.lock"
LOCK_TIMEOUT_SECONDS="${LOCK_TIMEOUT_SECONDS:-300}"
LOCK_RETRY_INTERVAL="${LOCK_RETRY_INTERVAL:-1}"
LOCK_RETRY_MAX="${LOCK_RETRY_MAX:-60}"

# --- Utility functions ---

log() {
  echo "[$(date -Iseconds)] $*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

# --- Atomic lock operations ---

acquire_lock_atomic() {
  # Use exec + open to achieve atomic O_EXCL behavior
  # This is the safest way to create a lock file atomically

  local lock_data=$(cat <<EOF
{
  "pid": $$,
  "ppid": $PPID,
  "startedAt": "$(date -Iseconds)",
  "bootstrapBin": "$BOOTSTRAP_BIN",
  "user": "$(whoami)",
  "hostname": "$(hostname)"
}
EOF
)

  # Try to create lock file atomically (fail if exists)
  if (set -C; echo "$lock_data" > "$LOCK_FILE") 2>/dev/null; then
    return 0  # success
  else
    return 1  # already locked
  fi
}

release_lock() {
  if [ -f "$LOCK_FILE" ]; then
    rm -f "$LOCK_FILE"
    log "Lock released: $LOCK_FILE"
  fi
}

check_lock_age() {
  # Check if lock file is older than timeout
  if [ ! -f "$LOCK_FILE" ]; then
    return 0  # no lock
  fi

  local lock_mtime=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
  local now=$(date +%s)
  local age=$((now - lock_mtime))

  if [ "$age" -gt "$LOCK_TIMEOUT_SECONDS" ]; then
    log "Lock expired (age: ${age}s, timeout: ${LOCK_TIMEOUT_SECONDS}s). Removing."
    rm -f "$LOCK_FILE"
    return 0  # lock expired, proceed
  fi

  return 1  # lock still valid
}

check_lock_holder_alive() {
  # Check if the PID in lock file is still alive
  if [ ! -f "$LOCK_FILE" ]; then
    return 1  # no lock
  fi

  local lock_pid=$(grep -o '"pid": [0-9]*' "$LOCK_FILE" | grep -o '[0-9]*' || echo "")

  if [ -z "$lock_pid" ]; then
    log "Malformed lock file. Removing."
    rm -f "$LOCK_FILE"
    return 0
  fi

  if ! kill -0 "$lock_pid" 2>/dev/null; then
    log "Lock holder (PID $lock_pid) is dead. Removing stale lock."
    rm -f "$LOCK_FILE"
    return 0  # lock is stale
  fi

  return 1  # lock holder is alive
}

# --- Cleanup ---

cleanup() {
  local exit_code=$?
  log "Bootstrap exit (code: $exit_code)"
  release_lock
  exit $exit_code
}

trap cleanup EXIT

# --- Main ---

main() {
  log "Bootstrap Guard v1.0 (PID: $$, PPID: $PPID)"

  # Step 1: Try to acquire lock immediately
  if acquire_lock_atomic; then
    log "Lock acquired: $LOCK_FILE"

    # Run bootstrap with this lock held
    log "Starting bootstrap: $BOOTSTRAP_BIN"
    exec node "$BOOTSTRAP_BIN" "$@"
  fi

  # Step 2: Lock exists. Check if we can recover it
  log "Lock file exists: $LOCK_FILE"

  # Check if lock is expired
  if check_lock_age; then
    log "Trying lock again after expiry check..."
    if acquire_lock_atomic; then
      log "Lock acquired after cleanup"
      exec node "$BOOTSTRAP_BIN" "$@"
    fi
  fi

  # Check if lock holder is dead
  if check_lock_holder_alive; then
    log "Trying lock again after stale check..."
    if acquire_lock_atomic; then
      log "Lock acquired after stale cleanup"
      exec node "$BOOTSTRAP_BIN" "$@"
    fi
  fi

  # Step 3: Lock is still held. Wait and retry
  local retry_count=0
  while [ $retry_count -lt $LOCK_RETRY_MAX ]; do
    log "Waiting for lock release... (retry $retry_count/$LOCK_RETRY_MAX)"
    sleep "$LOCK_RETRY_INTERVAL"

    retry_count=$((retry_count + 1))

    # Re-check lock validity
    if check_lock_age; then
      if acquire_lock_atomic; then
        log "Lock acquired after retry"
        exec node "$BOOTSTRAP_BIN" "$@"
      fi
    fi

    if check_lock_holder_alive; then
      if acquire_lock_atomic; then
        log "Lock acquired after retry"
        exec node "$BOOTSTRAP_BIN" "$@"
      fi
    fi
  done

  # Step 4: Give up
  die "Failed to acquire lock after $LOCK_RETRY_MAX retries. Already running?"
}

# --- Run ---

main "$@"
