#!/usr/bin/env bash
# CI log watcher daemon.
# Sau khi nhận signal (USR1/USR2) hoặc trigger file → theo dõi latest GitHub Actions run
# và snapshot log mỗi WATCH_INTERVAL giây (default 300 = 5 phút).
#
# Chạy nền:
#   bash tools/ci_watcher.sh &
# Gửi signal sau khi push:
#   bash tools/ci_watch.sh        (hoặc: pkill -USR1 -f ci_watcher.sh)
#   (hoặc: touch /tmp/ci_watcher_trigger)
#
# Env: CI_REPO, CI_BRANCH (default main), WATCH_INTERVAL (default 300), WATCH_TRIGGER

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${CI_REPO:-}"
if [[ -z "$REPO" ]]; then
  _URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null)"
  case "$_URL" in *github.com*|*git@github.com*) REPO="${_URL##*github.com[:/]}";; esac
  REPO="${REPO%.git}"
fi
[[ -n "$REPO" ]] || die "không xác định được CI_REPO (set CI_REPO=org/repo)"
BRANCH="${CI_BRANCH:-main}"
INTERVAL="${WATCH_INTERVAL:-300}"
TRIGGER="${WATCH_TRIGGER:-/tmp/ci_watcher_trigger}"
LOGDIR="$ROOT/logs/ci"
LAST_RUN=""

mkdir -p "$LOGDIR"
log(){ echo "[watcher $(date '+%H:%M:%S')] $*"; }
die(){ log "$*"; exit 1; }
command -v gh >/dev/null 2>&1 || die "cần gh (GitHub CLI)"
command -v jq >/dev/null 2>&1 || die "cần jq"

_SIG=0
trap '_SIG=1' USR1 USR2

# latest run (databaseId\tstatus) trên branch — rỗng nếu không có
latest_run(){ gh run list --repo "$REPO" --branch "$BRANCH" --limit 1 --json databaseId,status --jq '.[0] | [.databaseId,.status] | @tsv' 2>/dev/null; }

# append phần log MỚI (theo byte-diff) vào $LOGDIR/<run>.log + copy sang latest.log
append_new(){
  local run="$1"
  local full="$LOGDIR/.$run.full"
  gh run view --repo "$REPO" "$run" --log > "$full" 2>/dev/null || true
  local cur prev
  cur="$(wc -c < "$full" 2>/dev/null || echo 0)"
  prev="$(cat "$LOGDIR/.$run.size" 2>/dev/null || echo 0)"
  if [[ "$cur" -gt "$prev" ]]; then
    tail -c "$((cur-prev))" "$full" >> "$LOGDIR/$run.log"
    echo "$cur" > "$LOGDIR/.$run.size"
  fi
  rm -f "$full"
  cp "$LOGDIR/$run.log" "$LOGDIR/latest.log"
  # status summary (job progress) — có giá trị ngay cả khi log còn trống
  gh run view --repo "$REPO" "$run" 2>/dev/null > "$LOGDIR/$run.status.log"
  write_report "$run"
}

# Báo cáo MẪU ngắn gọn (opencode chỉ cần cat file này → đỡ token)
write_report(){
  local run="$1"
  local json status conclusion title branch
  json="$(gh run view --repo "$REPO" "$run" --json status,conclusion,displayTitle,headBranch 2>/dev/null)"
  status="$(echo "$json" | jq -r '.status // ""')"
  conclusion="$(echo "$json" | jq -r '.conclusion // "…"')"
  title="$(echo "$json" | jq -r '.displayTitle // ""' | cut -c1-60)"
  branch="$(echo "$json" | jq -r '.headBranch // ""')"
  {
    echo "[CI] #$run ($branch)"
    echo "TITLE : $title"
    echo "STATE : ${status:-?} · ${conclusion:-…}"
    echo "LOG   : $(wc -c < "$LOGDIR/$run.log" 2>/dev/null || echo 0) bytes ($run.log)"
    if [[ -f "$LOGDIR/$run.error.log" ]]; then
      echo "ERRS  : CÓ LỖI → logs/ci/$run.error.log"
    fi
  } > "$LOGDIR/report.txt"
  cp "$LOGDIR/report.txt" "$LOGDIR/latest_report.txt"
}

watch_run(){
  local run="$1" status="$2"
  : > "$LOGDIR/$run.log"
  rm -f "$LOGDIR/.$run.size" "$LOGDIR/.$run.full"
  log "== theo dõi run #$run [$status] — snapshot mỗi ${INTERVAL}s → $LOGDIR/$run.log =="
  while :; do
    status="$(gh run view --repo "$REPO" "$run" --json status --jq .status 2>/dev/null)"
    append_new "$run"
    log "snapshot run #$run -> $LOGDIR/$run.log ($(wc -l < "$LOGDIR/$run.log") lines)"
    if [[ "$status" == "completed" ]]; then
      append_new "$run"
      log "== run #$run DONE =="
      gh run view --repo "$REPO" "$run" 2>/dev/null | tee -a "$LOGDIR/$run.log"
      write_report "$run"
      # dump log-failed nếu build fail (để opencode đọc nhanh lỗi compile)
      local conclusion
      conclusion="$(gh run view --repo "$REPO" "$run" --json conclusion --jq .conclusion 2>/dev/null)"
      if [[ "$conclusion" == "failure" || "$conclusion" == "cancelled" ]]; then
        log "conclusion=$conclusion — dump log-failed → $LOGDIR/$run.error.log"
        gh run view --repo "$REPO" "$run" --log-failed 2>/dev/null > "$LOGDIR/$run.error.log"
        write_report "$run"
      fi
      return 0
    fi
    # chờ INTERVAL giây; signal giữa chừng → break để refresh (có thể có push mới)
    local i=0
    while [[ "$i" -lt "$INTERVAL" ]]; do
      sleep 5; i=$((i+5))
      if [[ "$_SIG" == 1 ]]; then _SIG=0; log "signal nhận — refresh run"; return 0; fi
    done
  done
}

log "CI watcher — repo=$REPO branch=$BRANCH interval=${INTERVAL}s"
log "Trigger: bash tools/ci_watch.sh   |   pkill -USR1 -f ci_watcher.sh   |   touch $TRIGGER"

while :; do
  if [[ "$_SIG" == 1 || -f "$TRIGGER" ]]; then
    _SIG=0; rm -f "$TRIGGER"
    IFS=$'\t' read -r run status <<<"$(latest_run)"
    if [[ -z "$run" ]]; then
      log "KHÔNG có run nào (Actions chưa trigger?) — retry 10s"
      sleep 10
    elif [[ "$run" == "$LAST_RUN" ]]; then
      log "run mới nhất vẫn #$run (chưa có push mới) — retry 8s"
      sleep 8
    else
      LAST_RUN="$run"
      watch_run "$run" "$status"
    fi
  fi
  sleep 2
done