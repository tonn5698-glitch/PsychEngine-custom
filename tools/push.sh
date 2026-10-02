#!/usr/bin/env bash
# Push rồi tự signal CI watcher (flow tiết kiệm token).
#   bash tools/push.sh origin main      # giống git push + trigger watcher
#   bash tools/push.sh -n origin main   # push KHÔNG trigger watcher
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
NO_WATCH=0
ARGS=()
for a in "$@"; do
  case "$a" in -n|--no-watch) NO_WATCH=1;; *) ARGS+=("$a");; esac
done
git -C "$ROOT" push "${ARGS[@]}"
if [[ "$NO_WATCH" == 1 ]]; then
  echo "[push] done (no watch)"
  exit 0
fi
bash "$DIR/ci_watch.sh"