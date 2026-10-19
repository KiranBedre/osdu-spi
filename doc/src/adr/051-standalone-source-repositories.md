# ADR-051: Standalone Source Repositories

## Status

Accepted

## Context

The SPI engineering system was built for long-lived forks. Initialization
therefore requires an upstream repository and creates `fork_upstream` from
that source.

Some SPI components are original deployment assets with no source repository
to mirror. A shared Airflow runtime image is one example: the Stack owns its
Dockerfile and dependency pins, while Apache Airflow is an image dependency,
not its source repository. Selecting an unrelated upstream would record false
provenance and activate synchronization that cannot produce valid updates.

These repositories still need the template's validation, image publication,
release, security, ruleset, and template synchronization controls.

## Decision

Add `SYNC_MODE=standalone` for an original repository with no upstream source.
It is selected by replying to the initialization issue with:

```text
mode: standalone
```

Initialization:

1. creates `fork_upstream` as an empty root commit;
2. creates `fork_integration` from that source baseline and applies the
   template-managed engineering system;
3. merges the initialized integration branch into `main`;
4. leaves application source owned directly by `main`;
5. does not set `UPSTREAM_REPO_URL`;
6. disables the scheduled upstream-sync job and upstream correlation tag; and
7. continues receiving engineering-system updates through template sync.

The empty source branch preserves the three-branch contract used by rulesets
and integration cleanup without claiming external provenance. Template sync
continues to stage updates through `fork_integration`, and normal production
merges keep that branch aligned with `main`.

Standalone mode is not used for a fork whose history is inconvenient to
publish. Snapshot and filtered-snapshot modes retain explicit source
provenance for those cases.

## Consequences

### Positive

- Original SPI components can use the same validation, release, and security
  system as onboarded services.
- Release metadata does not claim an unrelated upstream version.
- The repository can receive template fixes without upstream-sync noise.

### Negative

- Application source changes are maintained only in the SPI repository.
- The empty `fork_upstream` branch has no deployable tree and exists only as
  the source baseline required by the branch model.
- Downstream mirrors must treat the standalone repository itself as their
  upstream.

## Related Decisions

- [ADR-001: Three-Branch Strategy](001-three-branch-strategy.md)
- [ADR-006: Two-Workflow Initialization](006-two-workflow-initialization.md)
- [ADR-039: Customer-Tier Mirror Sync](039-customer-tier-mirror-sync.md)
- [ADR-049: Upstream Tip Snapshot Mode](049-upstream-tip-snapshot.md)
