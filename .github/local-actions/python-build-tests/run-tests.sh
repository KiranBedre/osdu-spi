#!/usr/bin/env bash
# Copyright © Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="$HERE/../../actions/python-build"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$TMP/repo/.spi/ci"
touch "$TMP/repo/requirements.txt" "$TMP/repo/requirements-tests.in"
cat > "$TMP/repo/.spi/ci/build.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '<testsuite tests="1" failures="0" errors="0"/>\n' > "$SPI_TEST_REPORT"
printf '<coverage/>\n' > "$SPI_COVERAGE_FILE"
EOF

(cd "$TMP/repo" && \
  GITHUB_OUTPUT="$TMP/config.out" \
  WORKING_DIRECTORY=. PYTHON_VERSION=3.11 REQUIREMENTS_FILE=requirements.txt \
  AIRFLOW_VERSION= DAG_PATH= DAG_ID= \
  TEST_REQUIREMENTS_FILE=requirements-tests.in BUILD_SCRIPT=.spi/ci/build.sh \
  TEST_REPORT=.spi/results/test-results.xml COVERAGE_FILE=.spi/results/coverage.xml \
  "$ACTION/validate-inputs.sh")
grep -q '^requirements_file=requirements.txt$' "$TMP/config.out" || die "root requirements path changed"

(cd "$TMP/repo" && \
  GITHUB_OUTPUT="$TMP/build.out" BUILD_SCRIPT=.spi/ci/build.sh SPI_SOURCE_PATH=. \
  SPI_TEST_REPORT=.spi/results/test-results.xml SPI_COVERAGE_FILE=.spi/results/coverage.xml \
  "$ACTION/run-build.sh")
grep -q '^build_result=success$' "$TMP/build.out" || die "successful build result missing"

mkdir -p "$TMP/repo/src/dags" "$TMP/fake-airflow/airflow"
touch "$TMP/fake-airflow/airflow/__init__.py" "$TMP/repo/src/dags/demo.py"
cat > "$TMP/fake-airflow/airflow/models.py" <<'EOF'
class DagBag:
    def __init__(self, dag_folder, include_examples, safe_mode):
        self.import_errors = {}
        self.dags = {"demo_dag": object()}
EOF
(cd "$TMP/repo" && \
  PYTHONPATH="$TMP/fake-airflow" DAG_PATH=src/dags/demo.py DAG_ID=demo_dag \
  EVIDENCE_PATH=.spi/results/airflow-dag.json \
  python3 "$ACTION/verify-airflow-dag.py")
grep -q '"dagId": "demo_dag"' "$TMP/repo/.spi/results/airflow-dag.json" \
  || die "Airflow evidence missing expected DAG"

RC=0
(cd "$TMP/repo" && \
  GITHUB_OUTPUT="$TMP/airflow-bad.out" WORKING_DIRECTORY=. PYTHON_VERSION=3.12 \
  AIRFLOW_VERSION=3.2 DAG_PATH=src/dags/demo.py DAG_ID=demo_dag \
  REQUIREMENTS_FILE=requirements.txt TEST_REQUIREMENTS_FILE=requirements-tests.in \
  BUILD_SCRIPT=.spi/ci/build.sh TEST_REPORT=.spi/results/test-results.xml \
  COVERAGE_FILE=.spi/results/coverage.xml "$ACTION/validate-inputs.sh") >/dev/null 2>&1 || RC=$?
[ "$RC" -eq 2 ] || die "Airflow version must be exact"

RC=0
(cd "$TMP/repo" && \
  GITHUB_OUTPUT="$TMP/bad.out" WORKING_DIRECTORY=../escape PYTHON_VERSION=3.11 \
  AIRFLOW_VERSION= DAG_PATH= DAG_ID= \
  REQUIREMENTS_FILE=requirements.txt TEST_REQUIREMENTS_FILE=requirements-tests.in \
  BUILD_SCRIPT=.spi/ci/build.sh TEST_REPORT=.spi/results/test-results.xml \
  COVERAGE_FILE=.spi/results/coverage.xml "$ACTION/validate-inputs.sh") >/dev/null 2>&1 || RC=$?
[ "$RC" -eq 2 ] || die "path traversal must exit 2"

grep -q 'maven-jar|source|source-direct|artifact' \
  "$HERE/../../actions/docker-build/action.yml" \
  || die "docker-build must accept direct Python source"
grep -q 'id: source-metadata' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must compute image metadata"
grep -q 'echo "build_date=' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must pass build_date"
grep -q 'echo "commit_id=' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must pass commit_id"
grep -q 'echo "commit_branch=' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must pass commit_branch"
grep -q 'echo "commit_message=' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must pass commit_message"
grep -q 'echo "release_version=' "$HERE/../../actions/docker-build/action.yml" \
  || die "direct source builds must pass release_version"
grep -q "'source-direct'" "$HERE/../../template-workflows/validate.yml" \
  || die "validation workflow must select direct Python source"
grep -q "cut -d. -f1,2" "$ACTION/action.yml" \
  || die "Airflow constraints must use the Python major.minor version"

echo "ok: Python build action contract"
