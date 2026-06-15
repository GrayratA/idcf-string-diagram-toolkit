# Correctness differential testing: toolkit vs `cfid`

This directory contains a **differential-testing harness** for the counterfactual
identification toolkit. It runs the toolkit and the reference R package
[`cfid`](https://cran.r-project.org/package=cfid) on the *same* large set of
generated problems and checks that they agree on whether each query is
**identifiable**.

It's meant to be picked up and extended by whoever maintains the tool. The
"Why this exists" section explains the problem it addresses and how to use the
results in the report/paper.

---

## Why this exists (the problem it solves)

Right now the toolkit's correctness rests on no formal proof plus a handful of
hand-picked end-to-end ("system") runs, while the prose says the software is
correct. It would be good to back the claim up better.

The tool implements a known algorithm (ID-CF / counterfactual identification on
ADMGs). For that kind of tool, a practical way to build correctness evidence —
short of a formal proof — is to compare it against an independent reference
implementation on a large, systematically generated set of inputs, rather than a
few hand-picked runs.

`cfid` is a good reference: it's the published R implementation of the ID\*/IDC\*
counterfactual identification algorithms. If, across many generated ADMGs, the
toolkit and `cfid` agree on **identifiable vs non-identifiable** (and agree on
the failures too, not just the successes), that gives a concrete, quantified
claim:

> *"On N generated counterfactual identification problems spanning chains,
> fan-ins, dense DAGs and confounded graphs, the toolkit's identifiability
> verdict agreed with the `cfid` reference on 100% of comparable cases,
> including all non-identifiable cases."*

which is more useful than a bare "the software is correct".

### Why compare the verdict and not the formula

Identifiability (ID vs FAIL) is a property of the tuple
`(graph, target events γ, evidence events δ, data type)`. It doesn't depend on
how the events are grouped into "worlds", nor on the surface syntax of the
resulting estimand. Two tools can return equivalent-but-differently-written
estimands and both be correct, so comparing formula strings is noisy. The ID/FAIL
verdict is a clean, tool-independent fact, so a disagreement on it points at
something real worth investigating. (Numerical estimand equivalence is a natural
next layer; see "Extending".)

### A second, related gap it helps with

The **four synthetic DAGs** used for the efficiency benchmarks were never checked
for correctness, so it's unclear whether the efficiency numbers measure correct
computations. The corpus here includes those four families (`chain`, `fanin`,
`dense`, `chain_bi`) as named cases, so they get a correctness verdict and not
just a timing.

---

## What it does (pipeline)

```
gen_corpus.py  ─►  corpus.{json,jl,R}      one corpus, three native encodings
                        │
        ┌───────────────┼────────────────┐
        ▼                                 ▼
   run_julia.jl                      run_cfid.R
 (the toolkit)                    (cfid reference)
        │                                 │
        ▼                                 ▼
 verdicts_julia.tsv                verdicts_cfid.tsv
        └───────────────┬────────────────┘
                        ▼
                   compare.py  ─►  report.md  (+ non-zero exit on disagreement)
```

Each **case** is a counterfactual identification problem:

```jsonc
{
  "id": "drug",
  "directed":   [["X","W"],["W","Y"],["D","Z"],["Z","Y"]],
  "bidirected": [["X","Y"]],                 // latent confounding
  "data": "interventions",                    // or "observations"
  "target":   [{"var":"Y","val":"y","do":{"X":"x"}}],          // γ
  "evidence": [{"var":"X","val":"xt","do":{}},                 // δ
               {"var":"D","val":"d","do":{}},
               {"var":"Z","val":"z","do":{"D":"d"}}]
}
```

A *counterfactual event* `{var, val, do}` is the potential outcome "`var = val` in
the world where the `do` variables are intervened". This maps directly onto:

* **`cfid`**: `cf(var, obs, sub)`, combined with `conj(...)`, then
  `identifiable(g, γ, δ, data)`.
* **the toolkit**: a list of `CounterfactualQuery` worlds passed to
  `identify_counterfactual(...)`, whose `.identifiable` field is the verdict.

The corpus is **reproducible** (seeded RNG) and mixes:

* **structured cases** — the classic `drug` (identifiable from interventions) and
  `party` (identifiable from observations) examples, plus the four synthetic
  efficiency-benchmark families at small sizes;
* **random cases** — seeded random ADMGs of varying size and edge density,
  including bidirected (confounding) edges that produce genuine non-identifiable
  queries, so the *FAIL* side is exercised too.

---

## Requirements

| Component | Needs |
| --- | --- |
| `gen_corpus.py`, `compare.py` | Python 3 (standard library only) |
| `run_julia.jl` | Julia + this repo's project deps (`julia --project=<repo-root> -e 'using Pkg; Pkg.instantiate()'`) |
| `run_cfid.R` | R + the `cfid` package (`install.packages("cfid")`) |

> Note: this harness was authored without Julia/R available in the authoring
> environment, so the Python pieces are tested but the `run_julia.jl` /
> `run_cfid.R` runners have **not yet been executed**. The first run on a machine
> with the full toolchain may need minor fixes (see "First-run checklist").

---

## How to run

```bash
# from this directory
./run_all.sh 60 1          # 60 random cases, RNG seed 1
```

or step by step:

```bash
python3 gen_corpus.py --n 60 --seed 1 --out .
julia --project=../.. run_julia.jl corpus.jl verdicts_julia.tsv
Rscript run_cfid.R corpus.R verdicts_cfid.tsv
python3 compare.py corpus.json verdicts_julia.tsv verdicts_cfid.tsv report.md
```

Read `report.md`. The script **exits non-zero if there is any disagreement**, so
it doubles as a CI gate.

### Interpreting the outcome of each case

| Outcome | Meaning |
| --- | --- |
| **AGREE** | both tools returned a verdict (ID/FAIL) and they match — good |
| **DISAGREE** | both returned a verdict but they differ — worth investigating |
| **NOT-COMPARABLE** | at least one tool returned `ERROR` (a crash, or a case the runner mis-translated / the tool doesn't support) — review, but not a correctness counterexample on its own |

`ERROR` from the toolkit is split out deliberately: a clean *FAIL* (the toolkit's
Step 4 raising a recognised `FAIL (...)`) is a genuine "non-identifiable" verdict,
whereas a build/simplify crash or an unrecognised error is a robustness issue to
look at separately — not silently counted as agreement or disagreement.

---

## First-run checklist (for the maintainer)

When you first run this with the real toolchain, sanity-check these — they are the
places most likely to need a one-line adjustment, because they encode assumptions
about the toolkit's API that were read from the source but not executed:

1. **Include order / paths in `run_julia.jl`** — mirrors
   `comparisons/runtime/julia_benchmark.jl`; adjust if `src/` layout changed.
2. **`identify_counterfactual` return fields** — the runner reads
   `.identifiable`, `.failure_stage`, `.error`. Confirm those names.
3. **The `FAIL` heuristic** — `run_julia.jl` treats a Step-4 error whose message
   contains the substring `"FAIL"` as a non-identifiability verdict. If the
   toolkit signals non-identifiability differently, update `verdict_of`.
4. **`cfid` query API** — `run_cfid.R` uses `dag()`, `cf(var, obs, sub)`,
   `conj()`, `identifiable(g, γ, δ, data=)`, `res$id`. Pin the `cfid` version you
   used and check the signatures match.
5. **Start small**: `./run_all.sh 5 1`, eyeball `report.md`, then scale `N` up.

The known `drug` and `party` cases are a good first check: if the harness is
wired correctly, both tools should return ID for them.

---

## How to integrate the results into the report / paper

1. **Run it, commit `report.md`** (or a copy under a results dir). The generated
   `corpus.*` and `verdicts_*.tsv` are git-ignored; the *seed* makes them
   reproducible, so cite the seed and `N`.
2. **Replace the bare correctness claim.** Swap "the software is correct" for the
   quantified statement: *N cases, agreement rate, all non-identifiable cases
   agreed, seed X*. State the oracle explicitly (`cfid`, version).
3. **Add a "Correctness testing" subsection** describing the three layers of
   evidence the project now has: (a) module unit tests in `test/`; (b) this
   cross-tool differential test on a generated corpus; (c) the numerical
   ground-truth checks in `comparisons/runtime/` (comb disintegration vs
   `pyAgrum`). Name the oracle for each.
4. **Close the second gap**: report the verdicts for the four synthetic
   benchmark DAGs here, so the efficiency results rest on correctness-checked
   inputs.
5. **Wire it into CI** (optional): `run_all.sh` exits non-zero on any
   disagreement, so it can guard against regressions as the toolkit evolves.

---

## Extending

* **More queries per graph** — `gen_corpus.py:natural_query` currently builds one
  target + a small evidence set. Generalise it to multi-target γ or richer δ.
* **Numerical estimand equivalence** — the natural next layer: parameterise each
  identifiable SCM, evaluate both tools' estimands, and assert equal numbers.
  This upgrades "same verdict" to "same answer".
* **`y0` as a second oracle** — `comparisons/runtime/python_y0_benchmark.py` shows
  how to read an ID/FAIL verdict out of `y0.algorithm.identify.idc_star`. Adding a
  `run_y0.py` runner and a three-way comparison strengthens the result further.
* **Markov-property validation** — orthogonal to identification, but the other
  open gap: check that the generated/benchmark DAGs admit a Markov factorisation
  before they are used for numerical experiments.

---

## File map

| File | Role |
| --- | --- |
| `gen_corpus.py` | generate the corpus; emit `corpus.{json,jl,R}` |
| `run_julia.jl` | run the toolkit; emit `verdicts_julia.tsv` |
| `run_cfid.R` | run the `cfid` reference; emit `verdicts_cfid.tsv` |
| `compare.py` | compare verdicts; write `report.md`; non-zero exit on disagreement |
| `run_all.sh` | orchestrate the four steps |
