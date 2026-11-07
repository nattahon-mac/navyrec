#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/clang-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swiftc -parse-as-library QuickRecorder/Supports/RecordingLevels.swift Tests/RecordingLevelsTests.swift -o .build/test-levels
.build/test-levels
