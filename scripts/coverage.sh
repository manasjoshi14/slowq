#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MIN_COVERAGE_FILE="${ROOT_DIR}/.quality/coverage_min.txt"
if [[ ! -f "$MIN_COVERAGE_FILE" ]]; then
    echo "Missing coverage threshold file: $MIN_COVERAGE_FILE"
    exit 1
fi

MIN_COVERAGE="$(tr -d '[:space:]' < "$MIN_COVERAGE_FILE")"
TEST_BINARY="$(find .build -type f -path '*.xctest/Contents/MacOS/*' -perm -111 | head -n 1)"
PROFILE="$(find .build -type f -name '*.profdata' | head -n 1)"
SOURCE_FILES=()
while IFS= read -r source_file; do
    SOURCE_FILES+=("$source_file")
done < <(find Sources/SlowQ -type f -name '*.swift' | sort)

if [[ -z "$TEST_BINARY" || -z "$PROFILE" || ${#SOURCE_FILES[@]} -eq 0 ]]; then
    echo "Coverage artifacts not found. Run: swift test --enable-code-coverage"
    exit 1
fi

REPORT="$(xcrun llvm-cov report "$TEST_BINARY" -instr-profile "$PROFILE" "${SOURCE_FILES[@]}")"
echo "$REPORT"

ACTUAL_COVERAGE="$(echo "$REPORT" | awk '$1 == "TOTAL" {value = $10; gsub("%", "", value); print value}')"
if [[ -z "$ACTUAL_COVERAGE" ]]; then
    echo "Failed to parse TOTAL line coverage from llvm-cov output."
    exit 1
fi

if awk "BEGIN { exit !(${ACTUAL_COVERAGE} >= ${MIN_COVERAGE}) }"; then
    echo "Coverage gate passed: ${ACTUAL_COVERAGE}% >= ${MIN_COVERAGE}%"
else
    echo "Coverage gate failed: ${ACTUAL_COVERAGE}% < ${MIN_COVERAGE}%"
    exit 1
fi
