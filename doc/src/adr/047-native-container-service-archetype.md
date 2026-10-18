# ADR-047: Native Container Service Archetype

## Status

Accepted

## Context

Some OSDU deliverables are native executables built by CMake and shipped only
as container images. They do not expose a Maven, Node, or Python package build
that the existing service archetypes can validate. Building only the final
container can publish an executable whose native test suite never ran.

The service Dockerfile remains the source of truth for compiler packages,
native libraries, CMake options, and the runtime image. CI needs a stable way
to run the Dockerfile's tests and require machine-readable evidence without
reimplementing the native build in a workflow.

## Decision

Add `native-container-azure` as a schema version 4 service archetype.

The descriptor declares:

- a repository-relative `sourcePath`;
- image `context` and `dockerfile`; and
- script acceptance suites.

The Dockerfile exposes a fixed target named `spi-test`. Building that target
runs the native test suite and exports a CTest JUnit report at `/ctest.xml`.
The build action fails when the report is missing or unreadable,
when no test executed, or when any test failed or errored. It publishes the
report as native test evidence.

The deployable image copies its installed artifacts from the build stage that
ran the tests. Docker image validation and publication run only after the
native test action succeeds. Pull request validation tests `linux/amd64`; the
trusted publication lane defaults to `linux/amd64,linux/arm64`. A native
container can declare `service.image.platforms: linux/amd64` when its tests or
deployment target do not support arm64.

## Consequences

### Positive

- Native compiler and library choices stay in the service-owned Dockerfile.
- Publication requires CTest evidence with at least one executed test.
- The same descriptor routes standalone, pull request, Dependabot, summary,
  and image publication workflows.
- The final image can remain small because `spi-test` exports only JUnit XML.

### Negative

- A native service Dockerfile must maintain the fixed target and report path.
- The image build runs after the test-target build, although BuildKit caches
  can reuse layers.
- Pull request tests run only on `linux/amd64`; multi-architecture failures
  can first appear in the trusted publication lane.
- An amd64-only descriptor does not provide an arm64 image, and the service
  owner must expand the platform contract before deploying to arm64 nodes.

## Related Decisions

- [ADR-036: Workflow Trust Boundaries for CI/CD](036-workflow-trust-boundaries.md)
- [ADR-037: Engineering System Owns the Canonical Service Dockerfile](037-engineering-system-owns-service-dockerfile.md)
- [ADR-040: Descriptor-Owned Acceptance Contract](040-descriptor-acceptance-contract.md)
- [ADR-046: Airflow DAG Service Archetype](046-airflow-dag-service-archetype.md)
- [ADR-048: Source-Owned Companion Image](048-source-owned-companion-image.md)
