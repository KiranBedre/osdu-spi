# ADR-046: Airflow DAG Service Archetype

## Status

Accepted

## Context

Some OSDU ingestion services are Airflow DAGs rather than HTTP processes.
Their deployable artifact is an Airflow runtime image containing the DAG and
its Python dependencies. Treating one as a FastAPI service would validate the
wrong runtime and would not prove that Airflow can parse the deployed DAG.

The Stack uses KubernetesExecutor, so the scheduler, DAG processor, and worker
pods must share one compatible Airflow and dependency set. A successful unit
test is not evidence that the exact Stack Airflow version imports the DAG.

## Decision

Add `airflow-dag-azure` as a schema version 4 service archetype.

The descriptor declares:

- a repository-relative `sourcePath`;
- `pythonVersion` and an exact `airflowVersion`;
- the rendered `dagPath` and expected `dagId`;
- source image `context` and `dockerfile`; and
- script acceptance suites.

The Python build action installs the declared Airflow version using its
official constraints for the declared Python runtime. It then installs the
service and test requirements and runs the fork-owned `.spi/ci/build.sh`.

After that script emits the standard JUnit and coverage reports, an Airflow
`DagBag` parses the declared DAG file. Import errors, or the absence of the
declared DAG ID, fail the build. The action publishes a deterministic JSON
report containing the parsed DAG IDs and import errors.

The service image remains a source build. Its Dockerfile must use the same
Airflow and Python versions declared by the descriptor and must pin its base
image by digest. The Stack deploys the resulting image by digest.

## Consequences

### Positive

- DAG compatibility is tested against the exact declared Airflow release.
- Parse evidence is machine-readable and controls the build verdict.
- DAG services reuse the existing source-image, acceptance-image, and
  Borrow, Prove, Restore paths.
- Service-specific rendering and unit tests remain fork-owned.

### Negative

- Installing Airflow makes the Python build lane slower.
- The descriptor and Dockerfile carry matching version declarations that
  reviewers must keep aligned.
- Conversion or task images launched by a DAG require a separate companion
  image contract in the Stack.

## Related Decisions

- [ADR-037: Engineering System Owns the Canonical Service Dockerfile](037-engineering-system-owns-service-dockerfile.md)
- [ADR-040: Descriptor-Owned Acceptance Contract](040-descriptor-acceptance-contract.md)
- [ADR-041: Borrow, Prove, Restore Lane](041-borrow-prove-restore-lane.md)
- [ADR-045: Python and FastAPI Service Archetype](045-python-fastapi-service-archetype.md)
