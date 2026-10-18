# ADR-048: Source-Owned Companion Image

## Status

Accepted

## Context

Some OSDU repositories produce two runtime artifacts from one source commit.
The ZGY converter, for example, produces a native conversion image and an
Airflow DAG that launches it. Publishing only the primary image loses the
source relationship between the executable and the orchestration contract.

The shared SPI Airflow deployment must assemble DAGs from several service
repositories. A service repository therefore cannot replace the complete
Airflow runtime whenever its DAG changes.

The template already reserves `-acceptance` and `-load` packages for artifacts
with independent lifecycle contracts. Inferring another package from files in
the repository would make publication and release behavior implicit.

## Decision

Schema version 4 may declare one `service.companion`. The primary service keeps
its existing archetype and image contract. The companion declares:

- a report name;
- a closed validation `kind`;
- an explicit GHCR `packageSuffix`;
- the source and runtime versions needed by that validation kind; and
- its own image context and Dockerfile.

The first supported kind is `airflow-dag`. It declares the same Python,
Airflow, DAG path, and DAG ID contract as the Airflow service archetype.
Validation runs the exact-version `DagBag` check before either image can be
published.

The companion image uses the primary package name plus `packageSuffix`. The
trusted publication lane gives both images the same `sha-<commit>` tag, and the
release lane retags both from that immutable commit tag. `-acceptance` and
`-load` remain reserved.

The companion image is a source-owned DAG layer, not a second Airflow control
plane. The Stack assembles DAG layers into its shared Airflow runtime and owns
the atomic pin, reset, backfill, and restore behavior for the primary and
companion digests.

One companion is supported because the Stack lifecycle contract currently
advances one primary-companion pair. Additional companion kinds or cardinality
require a new decision and matching Stack support.

## Consequences

### Positive

- One source commit names both the native executable and its DAG contract.
- Pull requests validate both artifacts before image construction.
- Trusted publication and release cannot silently omit the declared companion.
- Multiple DAG services can coexist in one Stack-owned Airflow runtime.
- Package naming is explicit and does not depend on repository file discovery.

### Negative

- Source repositories with a companion run an additional Python and image
  build.
- The template workflows carry companion outputs through validation,
  Dependabot, publication, summaries, and release retagging.
- The initial contract supports only an Airflow DAG companion.

## Related Decisions

- [ADR-036: Workflow Trust Boundaries for CI/CD](036-workflow-trust-boundaries.md)
- [ADR-040: Descriptor-Owned Acceptance Contract](040-descriptor-acceptance-contract.md)
- [ADR-041: Borrow, Prove, Restore Lane](041-borrow-prove-restore-lane.md)
- [ADR-046: Airflow DAG Service Archetype](046-airflow-dag-service-archetype.md)
- [ADR-047: Native Container Service Archetype](047-native-container-service-archetype.md)
