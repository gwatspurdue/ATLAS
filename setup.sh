#!/bin/bash

draw_bar() {
  local count=$1
  local total=$2
  local width=40

  local filled=$((count * width / total))
  local empty=$((width - filled))
  local percent=$((count * 100 / total))

  # Move to fixed screen position (row, col 1)
  printf "\033[%d;1H\033[2K" "$BAR_ROW"

  printf "[%.*s%*s] %3d%% (%d/%d) Singularity builds\n" \
    "$filled" "########################################" \
    "$empty" "" \
    "$percent" "$count" "$total"
}


# Check if output directory argument is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <output_directory>"
  exit 1
fi

OUTPUT_DIR="$1"

# Check if output directory is not empty
if [ -z "$OUTPUT_DIR" ]; then
  echo "Output directory cannot be empty."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

mkdir -p containers
cd containers

REPO_FILE="../info/repos.txt"
TOTAL=$(grep -c '[^[:space:]]' "$REPO_FILE")
COUNT=0
WIDTH=40

echo "Cloning repositories..."
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
sleep 2

cd ..
ROWS=$(tput lines)
BAR_ROW=$ROWS

# Build Singularity .sif files
BUILD_COUNT=0
TOTAL_BUILDS=$(find containers -name "*.def" | wc -l)

echo "Building Singularity containers..."
draw_bar 0 $TOTAL_BUILDS  # Initial progress bar

for def_file in containers/*/*.def; do
  if [ -f "$def_file" ]; then
    BUILD_COUNT=$((BUILD_COUNT + 1))
    dir=$(dirname "$def_file")
    sif_name=$(basename "$dir").sif
    
    draw_bar $BUILD_COUNT $TOTAL_BUILDS  # Update progress bar
    
    echo "Building $sif_name from $def_file..."
    cd "$dir"
    singularity build "$OUTPUT_DIR/$sif_name" "$(basename "$def_file")"
    cd - > /dev/null
  fi
done

printf "\033[?25h\n"
printf "\nAll Singularity containers have been built.\n"