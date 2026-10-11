# ADR-045: Python and FastAPI Service Archetype

## Status

Accepted

## Context

The template supports Java/Maven and Node/TypeScript services. Rock and Fluid
Sample DDMS is a Python 3.11 FastAPI service with a source Dockerfile,
requirements-based dependency management, pytest unit tests, and a pytest
acceptance suite. Treating it as a Node script service would select the wrong
build runtime and acceptance image.

Python acceptance tests import application modules outside the tests
directory, so an image containing only the declared suite path is incomplete.
The service also has its own lint and unit-test layout, which should remain
fork-owned rather than encoded as RAFS-specific workflow commands.

## Decision

Add `python-fastapi-azure` as a schema version 4 service archetype.

The descriptor declares:

- a repository-relative `sourcePath`, including `.` for a root application;
- `pythonVersion`;
- source image `context` and `dockerfile`; and
- script acceptance suites with argv tokens and JUnit report paths.

The reusable Python build action installs the runtime and test requirements,
then executes `.spi/ci/build.sh`. The fork owns that script and must emit the
standard JUnit and XML coverage files. This preserves service-specific test
selection while keeping evidence and workflow behavior consistent.

The canonical Python acceptance image installs `requirements.txt` and
`requirements-tests.in`, includes the repository source, runs as a non-root
user, and invokes the declared entrypoint through a Python argv-safe launcher.
Only complete `${NAME}` argument tokens are expanded. No shell command string
is evaluated.

The first supported acceptance runtime is Python 3.11. Adding another Python
runtime requires a pinned base image and an explicit compatibility update.

## Consequences

### Positive

- Python/FastAPI services use the same build, image, and Borrow, Prove, Restore
  paths as Java and Node services.
- Test commands remain owned by the service fork.
- API and acceptance images remain paired to one source commit.
- Pytest can import application modules without duplicating source under the
  tests directory.

### Negative

- The template maintains a third build runtime and acceptance image.
- Requirements-based dependency installation is the initial Python contract;
  other packaging systems require a later contract extension.
- The Python acceptance image contains more source than the Maven and Node
  suite images.

## Related Decisions

- [ADR-037: Engineering System Owns the Canonical Service Dockerfile](037-engineering-system-owns-service-dockerfile.md)
- [ADR-040: Descriptor-Owned Acceptance Contract](040-descriptor-acceptance-contract.md)
- [ADR-041: Borrow, Prove, Restore Lane](041-borrow-prove-restore-lane.md)
- [ADR-044: Node and TypeScript Service Archetype](044-node-typescript-service-archetype.md)
