#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$HERE/../../actions/dag-artifact/verify.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

make_artifact() {
  local root="$1"
  mkdir -p "$root"
  ROOT="$root" python3 - <<'PY'
import hashlib
import json
import os
import zipfile
from pathlib import Path

root = Path(os.environ["ROOT"])
with zipfile.ZipFile(root / "dag.zip", "w") as archive:
    archive.writestr("service/dag.py", "DAG_ID = 'demo'\n")
digest = hashlib.sha256((root / "dag.zip").read_bytes()).hexdigest()
(root / "dag.zip.sha256").write_text(f"{digest}  dag.zip\n", encoding="utf-8")
(root / "workflow.json").write_text(
    json.dumps(
        {
            "workflowName": "demo",
            "description": "Demo workflow",
            "registrationInstructions": {"dagName": "demo"},
        }
    ),
    encoding="utf-8",
)
PY
}

make_artifact "$TMP/good"
python3 "$VERIFY" "$TMP/good" > "$TMP/evidence.json"
grep -q '"workflowName": "demo"' "$TMP/evidence.json" \
  || die "valid artifact evidence is missing the workflow"

cp -R "$TMP/good" "$TMP/bad-checksum"
printf '%064d  dag.zip\n' 0 > "$TMP/bad-checksum/dag.zip.sha256"
if python3 "$VERIFY" "$TMP/bad-checksum" >/dev/null 2>&1; then
  die "checksum mismatch was accepted"
fi

cp -R "$TMP/good" "$TMP/bad-workflow"
printf '{"workflowName":"demo"}\n' > "$TMP/bad-workflow/workflow.json"
if python3 "$VERIFY" "$TMP/bad-workflow" >/dev/null 2>&1; then
  die "incomplete workflow registration was accepted"
fi

mkdir -p "$TMP/unsafe"
ROOT="$TMP/unsafe" python3 - <<'PY'
import hashlib
import json
import os
import zipfile
from pathlib import Path

root = Path(os.environ["ROOT"])
with zipfile.ZipFile(root / "dag.zip", "w") as archive:
    archive.writestr("../escape.py", "pass\n")
digest = hashlib.sha256((root / "dag.zip").read_bytes()).hexdigest()
(root / "dag.zip.sha256").write_text(f"{digest}  dag.zip\n", encoding="utf-8")
(root / "workflow.json").write_text(
    json.dumps(
        {
            "workflowName": "demo",
            "description": "Demo workflow",
            "registrationInstructions": {"dagName": "demo"},
        }
    ),
    encoding="utf-8",
)
PY
if python3 "$VERIFY" "$TMP/unsafe" >/dev/null 2>&1; then
  die "unsafe DAG zip path was accepted"
fi

grep -q 'application/vnd.osdu.airflow.dag.v1' \
  "$HERE/../../actions/dag-artifact/action.yml" \
  || die "OCI artifact media type is missing"
grep -q 'oras-project/setup-oras@22ce207df3b08e061f537244349aac6ae1d214f6' \
  "$HERE/../../actions/dag-artifact/action.yml" \
  || die "setup-oras is not pinned"
grep -q 'cd "$ARTIFACT_PATH"' "$HERE/../../actions/dag-artifact/action.yml" \
  || die "ORAS must publish root-level artifact names"
if grep -q '"${ARTIFACT_PATH}/dag.zip:application/zip"' \
    "$HERE/../../actions/dag-artifact/action.yml"; then
  die "ORAS layer titles must not include the workspace path"
fi

echo "ok: DAG artifact contract"
