# ADR-050: Filtered Upstream Snapshot Mode

## Status

Accepted

## Context

Filter mode removes source paths that the SPI fork does not own, but each
generated `fork_upstream` commit retains the source commit as a Git parent.
This preserves source history and attribution, but it also makes every object
in that history reachable from the destination.

Snapshot mode omits source ancestry, but it copies the current source tree
byte for byte. It cannot onboard a repository whose current tip contains a
blob that GitHub rejects, such as a file larger than 100 MB.

A repository can therefore require both transformations: remove classified
paths from the current source tree and omit the source graph that still
contains those paths.

## Decision

Add `SYNC_MODE=filtered-snapshot` for a first-tier repository whose accepted
tree is a deterministic subset of the current upstream tip and whose source
commit cannot be published.

Filtered snapshot mode:

1. materializes the upstream tip and applies `.github/upstream-filter.yml`;
2. uses the same fail-closed classification, report, ownership split, and
   Azure tree seeding as filter mode;
3. records the original commit in the `Upstream-Sha` trailer and the effective
   filter identity in `Filter-Rev`;
4. creates the first `fork_upstream` commit without a parent;
5. gives later generated commits only the prior `fork_upstream` tip as a
   parent;
6. does not fetch or publish source tags; and
7. continues receiving the SPI engineering system through template sync.

The mode is selected explicitly during initialization:

```text
https://community.opengroup.org/osdu/example
mode: filtered-snapshot
```

Its durable generation revision includes the mode, filter configuration,
filter engine, and branch generator. A change to any of these inputs
invalidates a prior no-op result and regenerates the tree.

Filtered snapshot mode is not a fallback for an arbitrary push failure. A
maintainer selects it only after identifying the rejected source objects,
classifying the paths that must not reach `fork_upstream`, and confirming that
the remaining generated tree satisfies GitHub policy. Content removed from
`fork_upstream` is fork-owned if it is added independently to
`fork_integration` or `main`.

## Consequences

### Positive

- Repositories with rejected objects in both the current tree and source
  history can use the existing three-branch flow.
- Filter changes remain deterministic, reviewable, and fail closed.
- Rejected source commits, blobs, and tags never become reachable from the
  destination repository.

### Negative

- Git history in the SPI repository cannot traverse into the original source
  graph.
- Source tags are not available in the destination repository.
- Paths removed by the filter no longer receive upstream changes.
- Commit-level blame before the first filtered snapshot requires the source
  repository.

## Related Decisions

- [ADR-001: Three-Branch Strategy](001-three-branch-strategy.md)
- [ADR-038: Upstream Filter Transform](038-upstream-filter-transform.md)
- [ADR-043: Intact Upstream Passthrough](043-intact-upstream-passthrough.md)
- [ADR-049: Upstream Tip Snapshot Mode](049-upstream-tip-snapshot.md)
