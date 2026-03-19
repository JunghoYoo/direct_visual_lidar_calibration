#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

docker build \
  -f "$SCRIPT_DIR/Dockerfile" \
  -t direct_visual_lidar_calibration_w_livox:noetic \
  "$REPO_ROOT"
