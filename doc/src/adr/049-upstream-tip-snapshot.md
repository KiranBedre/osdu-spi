# ADR-049: Upstream Tip Snapshot Mode

## Status

Accepted

## Context

Passthrough mode preserves the source commit as a parent of each generated
`fork_upstream` commit. This keeps source history and tags auditable, but it
also makes every object in that history reachable from the destination.

Some GitLab repositories contain deleted blobs that GitHub refuses to accept,
such as individual files larger than 100 MB. The current source tree can be
valid for GitHub while a passthrough push still fails because an old parent
references a rejected object. Rewriting the source history into Git LFS would
change every affected source commit ID and make later synchronization depend
on a separate rewrite pipeline.

## Decision

Add `SYNC_MODE=snapshot` for a first-tier repository whose current upstream
tree is valid for GitHub but whose source ancestry cannot be published.

Snapshot mode:

1. copies the upstream tip tree byte for byte;
2. records the original commit in the `Upstream-Sha` trailer;
3. creates the first `fork_upstream` commit without a parent;
4. gives later snapshot commits only the prior `fork_upstream` tip as a parent;
5. does not fetch or publish source tags;
6. skips filter configuration and Azure tree seeding; and
7. continues receiving the SPI engineering system through template sync.

The mode is selected explicitly during initialization:

```text
https://community.opengroup.org/osdu/example
mode: snapshot
```

The generated tree and durable no-op behavior match passthrough. The ancestry
does not: the original source commit must never become reachable from a
snapshot branch. The source URL and full SHA remain the provenance boundary.

Snapshot mode is not a fallback for an arbitrary push failure. A maintainer
selects it only after identifying a source-history object that the destination
will not accept and confirming that the current tip tree contains no rejected
objects.

## Consequences

### Positive

- Valid source trees can be onboarded without copying rejected historical
  objects into GitHub.
- Future syncs remain deterministic and use the existing three-branch flow.
- Original source commit IDs stay meaningful because no history rewrite is
  performed.

### Negative

- Git history in the SPI repository cannot traverse into the original source
  graph.
- Source tags are not available in the destination repository.
- Commit-level blame before the first snapshot requires the source repository.

## Related Decisions

- [ADR-001: Three-Branch Strategy](001-three-branch-strategy.md)
- [ADR-038: Upstream Filter Transform](038-upstream-filter-transform.md)
- [ADR-043: Intact Upstream Passthrough](043-intact-upstream-passthrough.md)
