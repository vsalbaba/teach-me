#!/bin/bash
# Example: ./afk.sh 6
set -eo pipefail

[ -z "$1" ] && echo "Usage: $0 <iterations>" && exit 1

for ((i=1; i<=$1; i++)); do
  echo "=== Iteration $i of $1 ==="
  ./once.sh

  if grep -q "RALPH_COMPLETE" .last-run.log 2>/dev/null; then
    echo "Done after $i iterations."
    exit 0
  fi
done
