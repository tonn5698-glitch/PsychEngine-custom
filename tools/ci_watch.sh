#!/usr/bin/env bash
# Gửi signal cho CI watcher (chạy sau khi push).
# - Nếu watcher đang chạy: gửi USR1
# - Nếu chưa: touch trigger file (watcher sẽ bắt khi chạy lên)

PID="$(pgrep -f 'ci_watcher.sh' | head -1)"
if [[ -n "$PID" ]]; then
  kill -USR1 "$PID" 2>/dev/null && echo "[ci_watch] signal USR1 → watcher pid $PID" && exit 0
  echo "[ci_watch] gửi signal thất bại"
  exit 1
fi
touch /tmp/ci_watcher_trigger
echo "[ci_watch] watcher chưa chạy — đã touch trigger file."
echo "           Chạy watcher: bash \"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci_watcher.sh\" &"
exit 0