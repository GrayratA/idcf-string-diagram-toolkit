# Diagnosis of Remaining Correctness Disagreements

This file records the current status of the correctness corpus after aligning
all cases to the interventional-data setting `P_*(O)` and filtering out queries
that reduce to a single ordinary interventional distribution.

## Current Result

The generator now rejects candidate queries that, after lightweight
consistency/irrelevance simplification, can be embedded into one intervention
world of the form

```text
P(Y | Z; do(X)).
```

Those cases are directly available from `P_*(O)` and therefore do not test the
cross-world part of counterfactual identification.

With seed `1`, `300` random cases, and random ADMGs over `5..8` nodes, the
current comparison is:

```text
total cases       : 310
comparable        : 310
agree             : 308
disagree          : 2
not comparable    : 0
agreement rate    : 99.4%
```

The generator also reports:

```text
filtered 51 single-world-reducible random candidates
```

## Remaining Disagreements

Both remaining disagreements are `Julia FAIL / cfid ID`. They are not
single-world-reducible under the current structural filter.

| Case | Julia | cfid | Diagnosis |
| --- | --- | --- | --- |
| `rand0048` | `FAIL` | `ID` | Confounded graph. The current diagrammatic simplification leaves the query outside the implemented Step-3/Step-4 success fragment, while `cfid` finds an interventional formula. |
| `rand0255` | `FAIL` | `ID` | Confounded graph with factual evidence plus a consistency-reducible evidence event. After filtering, it remains genuinely cross-world; `cfid` identifies it, but Julia fails before producing a formula. |

These are best treated as likely false negatives of the current Julia
diagrammatic pipeline. Fixing them would likely require a fuller
ID*/IDC*-style c-component fallback or a stronger diagrammatic completeness
argument, which is intentionally outside the current implementation scope.

## Relation to the Paper

The relevant paper proves soundness of the diagrammatic `id-cf` direction: when
the algorithm succeeds, the returned expression in terms of `P_*` is valid.
However, it does not give a fully formal categorical completeness theorem saying
that every algorithmic `FAIL` is truly non-identifiability. The Outlook section
explicitly lists proving completeness of `id-cf` as future work.

Therefore, the remaining two `FAIL` cases should not be reported as theoretical
non-identifiability results. They are better described as current implementation
limitations of the scoped diagrammatic pipeline.
