#!/bin/bash
set -eo pipefail

mkdir -p output results

prompt=$(cat prompt.md)
claude --dangerously-skip-permissions \
  --output-format stream-json \
  -p "$prompt" \
  | tee .last-run.log \
  | jq --unbuffered -rj '
      select(.type == "assistant")
      .message.content[]?
      | select(.type == "text")
      .text // empty
      | . + "\n"
    ' \
  | while IFS= read -r line; do
      printf '[%s] %s\n' "$(date '+%d/%b/%Y:%H:%M:%S %z')" "$line"
    done
