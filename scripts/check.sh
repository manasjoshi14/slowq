#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/lint.sh
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors --enable-code-coverage
./scripts/coverage.sh
