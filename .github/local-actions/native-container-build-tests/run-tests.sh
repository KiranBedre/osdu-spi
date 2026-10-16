#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="$HERE/../../actions/native-container-build"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/pass.xml" <<'EOF'
<testsuites><testsuite tests="2" failures="0" errors="0" skipped="1"/></testsuites>
EOF
python3 "$ACTION/verify-junit.py" "$TMP/pass.xml" >/dev/null

cat > "$TMP/fail.xml" <<'EOF'
<testsuite tests="1" failures="1" errors="0" skipped="0"/>
EOF
if python3 "$ACTION/verify-junit.py" "$TMP/fail.xml" >/dev/null 2>&1; then
  echo "FAIL: failing native tests were accepted" >&2
  exit 1
fi

cat > "$TMP/empty.xml" <<'EOF'
<testsuite tests="1" failures="0" errors="0" skipped="1"/>
EOF
if python3 "$ACTION/verify-junit.py" "$TMP/empty.xml" >/dev/null 2>&1; then
  echo "FAIL: an all-skipped native suite was accepted" >&2
  exit 1
fi

cat > "$TMP/invalid.xml" <<'EOF'
<testsuite tests="many" failures="0" errors="0" skipped="0"/>
EOF
if python3 "$ACTION/verify-junit.py" "$TMP/invalid.xml" >/dev/null 2>&1; then
  echo "FAIL: a non-numeric CTest count was accepted" >&2
  exit 1
fi

mkdir -p "$TMP/workspace/context" "$TMP/runner"
printf 'FROM scratch\n' > "$TMP/workspace/Dockerfile"
printf 'payload\n' > "$TMP/workspace/context/input.txt"
(
  cd "$TMP/workspace"
  GITHUB_WORKSPACE="$TMP/workspace" RUNNER_TEMP="$TMP/runner" \
    BUILD_CONTEXT=context DOCKERFILE_PATH=Dockerfile \
    bash "$ACTION/stage-context.sh"
)
test -f "$TMP/runner/spi-native-test-context/input.txt"
test -f "$TMP/runner/spi-native-test-context/.spi.Dockerfile"

if (
  cd "$TMP/workspace"
  GITHUB_WORKSPACE="$TMP/workspace" RUNNER_TEMP="$TMP/runner" \
    BUILD_CONTEXT=../context DOCKERFILE_PATH=Dockerfile \
    bash "$ACTION/stage-context.sh" >/dev/null 2>&1
); then
  echo "FAIL: a traversal build context was accepted" >&2
  exit 1
fi

echo "All native container build tests passed."
