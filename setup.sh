#!/bin/bash

mkdir -p containers
cd containers

REPO_FILE="../info/repos.txt"
TOTAL=$(grep -c '[^[:space:]]' "$REPO_FILE")
COUNT=0
WIDTH=40

while IFS= read -r repo || [ -n "$repo" ]; do
  COUNT=$((COUNT + 1))

  git clone --quiet "$repo" >/dev/null 2>&1

  PERCENT=$((COUNT * 100 / TOTAL))
  FILLED=$((COUNT * WIDTH / TOTAL))
  EMPTY=$((WIDTH - FILLED))

  printf "\r[%.*s%*s] %3d%% (%d/%d)" \
    "$FILLED" "########################################" \
    "$EMPTY" "" \
    "$PERCENT" "$COUNT" "$TOTAL"
done < "$REPO_FILE"
printf "\nAll repositories have been cloned.\n"

cd ..