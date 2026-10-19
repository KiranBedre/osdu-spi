#!/usr/bin/env bash
# Copyright © Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTOR="$HERE/../../actions/codeql-languages/detect.sh"
WORKFLOW="$HERE/../../template-workflows/codeql.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_languages() {
  local workspace="$1" expected="$2"
  local actual
  actual="$(bash "$DETECTOR" "$workspace")"
  [[ "$actual" == "$expected" ]] || {
    printf 'expected %s, got %s\n' "$expected" "$actual" >&2
    exit 1
  }
}

for extension in js mjs cjs ts mts cts; do
  workspace="$TMP/javascript-$extension"
  mkdir -p "$workspace/.spi/acceptance"
  touch "$workspace/.spi/acceptance/check.$extension"
  assert_languages "$workspace" '["javascript-typescript","actions"]'
done

mkdir -p "$TMP/python/.spi/tests"
touch "$TMP/python/.spi/tests/check.py"
assert_languages "$TMP/python" '["python","actions"]'

mkdir -p "$TMP/go/.spi/tests"
touch "$TMP/go/.spi/tests/check.go"
assert_languages "$TMP/go" '["go","actions"]'

mkdir -p "$TMP/ignored/.git/hooks"
touch "$TMP/ignored/.git/hooks/check.mjs"
assert_languages "$TMP/ignored" '["java-kotlin","actions"]'

mkdir -p "$TMP/template-tooling/.github/actions"
touch "$TMP/template-tooling/.github/actions/check.py"
assert_languages "$TMP/template-tooling" '["java-kotlin","actions"]'

mkdir -p "$TMP/multiple/.spi"
touch "$TMP/multiple/.spi/check.py" "$TMP/multiple/.spi/check.mjs"
assert_languages "$TMP/multiple" '["python","javascript-typescript","actions"]'

grep -q '^              - \.spi$' "$WORKFLOW" || {
  printf 'CodeQL workflow must scan source under .spi\n' >&2
  exit 1
}

printf 'CodeQL language detection tests passed\n'
