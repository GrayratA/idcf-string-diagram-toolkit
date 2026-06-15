# Counterfactual Identification via String Diagram Surgery

Counterfactual identification prototype based on Julia/Catlab.

## Repository Layout

- `src/`: core Julia implementation (`admg_compile`, `bn_import`, `simplify_cf`, `id_cf`, causal-inference utilities)
  - `src/123.ipynb` and `src/test.ipynb` are development-time testing notebooks and can be ignored.
- `test/`: Julia test suites (`admg_compile`, `simplify_cf`, `id_cf`)
- `net/`: Bayesian network structure files (for example `hepar2.net`)
- `tools/`: helper scripts (for example BN-to-ADMG conversion)
- `comparisons/`: benchmark scripts and comparison artifacts
  - `comparisons/runtime/`: primary Julia vs R runtime benchmarks
  - `comparisons/runtime/structural_tests/`: structural scaling scripts/data/profiles
- `trace/`: intermediate trace artifacts

## Setup

Prerequisites:

- Julia (project uses `Project.toml` / `Manifest.toml`)
- R with package `cfid` (for R-side benchmarks)

Install Julia dependencies:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Run Tests

Run full Julia tests:

```powershell
julia --project=. test/runtest.jl
```

## Demo Quickstart

If you want a reproducible run without editing code:

1. Run the default commute StringDiagram example:

```powershell
julia --project=. src/run_demo.jl
```

2. Run ADMG commute:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/commute_admg.jl --queries examples/queries/commute_queries.jl
```

3. Run ADMG drug:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/drug_admg.jl --queries examples/queries/drug_queries.jl
```

4. Run ADMG party:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/party_admg.jl --queries examples/queries/party_queries.jl
```

5. Run HEPAR2 conditional:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/hepar2_bn_admg.jl --queries examples/queries/hepar2_conditional_queries.jl
```

6. Disable trace files if desired:

```powershell
julia --project=. src/run_demo.jl --no-trace
```

7. Run StringDiagram drug:

```powershell
julia --project=. src/run_demo.jl --diagram examples/string_diagrams/drug_scm.jl --queries examples/queries/drug_queries.jl
```

8. Run StringDiagram party:

```powershell
julia --project=. src/run_demo.jl --diagram examples/string_diagrams/party_scm.jl --queries examples/queries/party_queries.jl
```

Example assets are separated under:
- `examples/string_diagrams/`: string diagram definitions
- `examples/admg_models/`: ADMG model inputs
- `examples/queries/`: counterfactual query sets

See `examples/README.md` for the file contract used by `src/run_demo.jl`.

## Counterfactual API (`identify_counterfactual`)

Use `identify_counterfactual` as the single entry point for:
- building the SCM/multiverse from a graph + queries,
- running simplify + Step4/Step5,
- returning identifiability status and formula text.

Load core files:

```julia
using Catlab
include("src/admg_compile.jl")
include("src/simplify_cf.jl")
include("src/id_cf.jl")
include("src/bn_import.jl")     # optional: only if you read .bif/.net
include("src/chyp_export.jl")   # optional: only if you set trace_dir
```

HEPAR2 three-world conditional example:

```julia
hepar2 = read_bn_structure("net/hepar2.net")
model = hepar2.model

queries = [
    CounterfactualQuery(:Real, Dict{Symbol, Symbol}(), Dict(:age => :age_obs, :sex => :sex_obs), Symbol[]),
    CounterfactualQuery(:CF_pbc, Dict(:age => :age_do), Dict(:pbc => :pbc_obs), Symbol[]),
    CounterfactualQuery(:CF_carc, Dict(:age => :age_do), Dict(:carcinoma => :carc_obs), Symbol[]),
]

res = identify_counterfactual(
    model,
    queries;
    display_syms=[:age, :sex, :pbc, :carcinoma],
    output_vars=["carcinoma"],
    data=Step5DataConfig(mode=:conditional_queries),
    display=Step5DisplayConfig(
        symbols=Dict("age" => "age", "sex" => "sex", "pbc" => "pbc", "carcinoma" => "carcinoma"),
        value_rename=Dict("age_do" => "age"),
    ),
    trace_dir="trace/HEPAR2", # optional
)

println("identifiable = ", res.identifiable)
println("formula      = ", res.data_tex)
println("failure_stage= ", res.failure_stage)
println("error        = ", res.error)
```

Key returned fields:
- `res.identifiable`: `true` if Step4 succeeds.
- `res.formula_available`: `true` if Step5 produced formula text.
- `res.raw_tex`, `res.simplified_tex`, `res.data_tex`: formula strings.
- `res.failure_stage`: `nothing` or one of `:build`, `:simplify`, `:step4`, `:step5`.
- `res.error`: error message string when failed.
- `res.step3_blockers`: unabsorbed lambda boxes before Step4.
- `res.trace_paths`: written `.chyp` paths when `trace_dir` is set.
- `res.timings_ms`: timing breakdown by stage.

Alias:
- `run_cf_pipeline(...)` is an alias of `identify_counterfactual(...)`.

Troubleshooting:
- If `res.identifiable == false`, check `res.failure_stage` and `res.error`.
- If you pass `trace_dir`, ensure `include("src/chyp_export.jl")` was loaded.

## Causal Inference API (`infer_causal_effect`)

The causal-inference extension currently implements a comb-disintegration path for finite discrete models. It is separate from the counterfactual ID-CF pipeline.

Current scope:
- Input: a Catlab string diagram, finite variable values, an observational joint probability table, and a user-supplied comb witness.
- Comb witness: the user provides observed context variables, intervention variables, bridge variables, and outcome variables.
- Basic form: if `context=[]`, the result is `P(outcome | do(intervention))`.
- Context-aware form: if context variables are provided, the result is `P(outcome | context, do(intervention))`.
- Structure check: internally the tool builds the comb boundary `A = context ∪ intervention`, identifies the `g` region automatically, treats all remaining internal boxes as the `f` region, and verifies the boundaries `g : A -> B` and `f : B -> A ⊗ C`. It first tries a fast candidate and then falls back to complete finite search over internal box partitions.
- Markov check: for diagram-aware calls, the tool checks the local Markov property before numerical computation when the supplied joint table contains all non-exogenous diagram variables. If the diagram contains hidden/internal variables that are not in the joint table, this check is skipped because the ordinary DAG Markov property is not valid for the observed marginal alone.
- Optional override: explicit `g_boxes` and `f_boxes` can still be supplied for debugging or controlled experiments, but they are not the normal interface.
- Computation: if the structure check succeeds, it computes the corresponding finite causal-effect channel.
- Output: computability status, the supplied or discovered `A/B/C` witness, readable `g`/`f` subdiagram boxes, the comb decomposition, and the effect channel.

Markov-property validation:
- A DAG alone is not enough to check the Markov property; the check needs a probability distribution or dataset.
- In `infer_causal_effect(diagram, joint_state; ...)` and the high-level keyword interface, this check is part of the pipeline when the joint state covers the diagram variables needed for an ordinary DAG Markov check.
- The current implementation supports finite-discrete validation against the supplied `JointState`.
- `validate_markov_property(model, joint_state)` checks the local Markov property for DAGs with no bidirected edges.
- `validate_markov_property(diagram, joint_state)` performs the same check using the DAG extracted from the Catlab diagram when no non-exogenous diagram variables are omitted from the joint state.
- ADMGs with bidirected edges are rejected by this check, because they require m-separation rather than the ordinary DAG local Markov property.

Minimal Markov check:

```julia
include("src/admg_compile.jl")
include("src/causal_inference.jl")

model = ADMGModel([:X => :Y, :Y => :Z], Pair{Symbol,Symbol}[])
joint = JointState(
    [
        FiniteVariable(:X, [0, 1]),
        FiniteVariable(:Y, [0, 1]),
        FiniteVariable(:Z, [0, 1]),
    ],
    probs,
)

markov = validate_markov_property(model, joint)
println("markov passed = ", markov.passed)
println("failures      = ", markov.failures)
println("error         = ", markov.error)
```

Run the smoking scenario:

```powershell
julia --project=. examples/causal_inference/smoking_scenario.jl
```

Minimal usage:

```julia
using Catlab
using Catlab.Theories
using Catlab.Programs
using Catlab.WiringDiagrams

include("src/causal_inference.jl")

result = infer_causal_effect(
    smoking_diagram;
    variables=[
        :S => ["no_smoke", "smoke"],
        :T => ["low_tar", "high_tar"],
        :C => ["no_cancer", "cancer"],
    ],
    probabilities=probs,
    comb_structure=CombStructure(
        context=Symbol[],
        intervention=[:S],
        bridge=[:T],
        outcome=[:C],
    ),
)
```

Context-aware usage:

```julia
result = infer_causal_effect(
    diagram;
    variables=variables,
    probabilities=probs,
    comb_structure=CombStructure(
        context=[:hospital],
        intervention=[:surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:ChHepatitis],
    ),
)
```

Important limitation:
- The current implementation assumes the observational joint distribution is already given.
- The string diagram is used to validate the comb structure; the numeric result is computed from the supplied joint table.
- The normal mode is: the user supplies `context/intervention/bridge/outcome`; the tool identifies `g`, assigns the remaining internal boxes to `f`, and checks the two required boundaries.
- Explicit `g_boxes`/`f_boxes` are only an advanced override. If they are used with `cover_all_boxes=true`, they must cover every internal box in the diagram.
- The automatic `g/f` recognizer is complete for the current syntactic comb-shape check on finite Catlab wiring diagrams, but the exhaustive fallback is exponential in the number of internal boxes.
- The tool does not yet attach stochastic matrices to individual Catlab boxes or compose those boxes to derive the joint distribution automatically.
- Therefore, the current feature is best described as diagram-validated comb inference from a given joint distribution, not a fully executable probabilistic string-diagram model.
- It is not yet a fully general causal inference engine for arbitrary diagrams and arbitrary causal-effect queries.

## Runtime Benchmarks

Run main runtime comparison:

```powershell
julia --project=. comparisons/runtime/julia_benchmark.jl 30 5
Rscript comparisons/runtime/r_cfid_benchmark.R 30 5
```

For benchmark fields, alignment notes, and structural-test workflow, see:

- `comparisons/runtime/README.md`

## Structural Scaling Benchmarks

Example:

```powershell
julia comparisons/runtime/structural_tests/scripts/struct_scaling_julia.jl 4 2 8,16,24,32 | Tee-Object -FilePath comparisons/runtime/structural_tests/raw/struct_julia_r4w2.txt
```

```powershell
Rscript comparisons/runtime/structural_tests/scripts/struct_scaling_r.R 4 2 8,16,24,32 | Tee-Object -FilePath comparisons/runtime/structural_tests/raw/struct_r_r4w2.txt
```

```powershell
pwsh -File comparisons/runtime/structural_tests/scripts/make_struct_csv.ps1 -Tag r4w2
```

## Utility Script

Convert `.bif`/`.net` Bayesian network structure to ADMG Julia literal:

```powershell
julia --project=. tools/import_bn_to_admg.jl <input.bif|input.net> [output.jl] [model_name]
```
