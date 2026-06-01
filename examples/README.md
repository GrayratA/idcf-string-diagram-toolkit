# Examples

This folder contains both supported input styles for `identify_counterfactual`:

- `examples/string_diagrams/`: StringDiagram inputs (Catlab diagram definitions built with `@present`/`@program`).
- `examples/admg_models/`: ADMG inputs (`ADMGModel` or BN-imported ADMG).
- `examples/queries/`: counterfactual query sets.

## Current Example Set

- StringDiagram:
  - `string_diagrams/commute_scm.jl`
  - `string_diagrams/drug_scm.jl`
  - `string_diagrams/party_scm.jl`
- ADMG:
  - `admg_models/commute_admg.jl`
  - `admg_models/drug_admg.jl`
  - `admg_models/party_admg.jl`
  - `admg_models/hepar2_bn_admg.jl`
- Queries:
  - `queries/commute_queries.jl`
  - `queries/drug_queries.jl`
  - `queries/party_queries.jl`
  - `queries/hepar2_conditional_queries.jl`

## Scenario Notes (Real-World Meaning)

- `commute` (`commute_scm.jl` / `commute_admg.jl` + `commute_queries.jl`)
  - Imagine a rainy Monday morning: conditions on the road (`W`) are already bad, and you still need to choose how to travel (`T`). That choice affects intermediate route dynamics (`M`, `L`) and ultimately your arrival quality (`Y`), such as delay. This scenario asks a practical "what if" question people care about all the time: under the same morning conditions, how likely is a different commute choice to change the final outcome? It is useful because it helps separate effects driven by background conditions from effects driven by your own decision.

- `drug` (`drug_admg.jl` / `drug_scm.jl` + `drug_queries.jl`)
  - Think of a patient with baseline risk (`X`) who receives a treatment decision (`D`). That decision changes a biological marker (`Z`), while another health pathway (`W`) also contributes to the final clinical outcome (`Y`). The point is not just to describe what happened, but to ask how the outcome might have changed under an alternative treatment while keeping the patient's observed context fixed. In practice, this turns retrospective observations into a more decision-oriented treatment comparison.

- `party` (`party_admg.jl` / `party_scm.jl` + `party_queries.jl`)
  - This is the classic Ann-Bob-Carl party story. Ann’s attendance (`A`) influences whether Bob (`B`) and Carl (`C`) go, and the chance of a scuffle (`S`) depends strongly on whether Bob and Carl are both there. In the observed event, Bob did not attend, but the counterfactual asks what would likely have happened if he had gone, while keeping the rest of the situation aligned with the same night. It is a natural "alternate history" question that makes counterfactual reasoning intuitive.

- `hepar2` (`hepar2_bn_admg.jl` + `hepar2_conditional_queries.jl`)
  - The HEPAR2 case moves from toy examples to a realistic medical network. For a patient with observed evidence such as `age`, `sex`, and `pbc`, we ask about the likelihood of `carcinoma` under a hypothetical age-related intervention, while preserving the rest of the observed context. This example shows that the same workflow used for small didactic stories can still operate on large clinical graphs with many background variables.

## Variable Glossary

- `commute` variables
  - `W`: upstream context driver (for example weather/day-level conditions).
  - `T`: travel choice/treatment-like decision variable.
  - `M`: intermediate behavior or route-related mediator.
  - `L`: downstream latent traffic-state/route-state mediator before the final outcome.
  - `Y`: final commute outcome (for example delay, travel time, or utility).
  - `R1`: latent shared disturbance creating unobserved dependence between `T` and `Y` in the ADMG form.
  - `UW`, `UT`, `UM`, `UL`, `UY`, `UR1`: exogenous noise terms used in the SCM/string-diagram construction.

- `drug` variables
  - `X`: baseline patient/context variable.
  - `W`: post-baseline intermediate clinical state.
  - `D`: intervention/treatment assignment.
  - `Z`: mediator affected by treatment.
  - `Y`: final clinical outcome.

- `party` variables
  - `A`: indicator for whether Ann goes to the party.
  - `B`: indicator for whether Bob goes to the party.
  - `C`: indicator for whether Carl goes to the party.
  - `S`: indicator for whether a scuffle happens.
  - `b` / `bp` in queries: two Bob-value tokens used for intervention vs observed-world conditioning (for example "Bob goes" vs "Bob does not go").

- `hepar2_conditional` variables (the ones explicitly queried/displayed)
  - `age`: patient age variable.
  - `sex`: patient sex variable.
  - `pbc`: a liver-disease-related clinical variable in HEPAR2.
  - `carcinoma`: target cancer outcome variable.
  - Note: the full HEPAR2 graph has many additional variables; this demo conditions/marginalizes over them automatically.

## File Contract

- Diagram/model file must return a `NamedTuple` with:
  - Required: `input`
  - Optional: `name`, `display_syms`, `output_vars`
- Query file must return a `NamedTuple` with:
  - Required: `queries`
  - Optional: `name`, `display_syms`, `output_vars`, `rules`, `display`, `data`

## Run

Default (StringDiagram commute):

```powershell
julia --project=. src/run_demo.jl
```

ADMG commute:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/admg_models/commute_admg.jl `
  --queries examples/queries/commute_queries.jl
```

ADMG drug:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/admg_models/drug_admg.jl `
  --queries examples/queries/drug_queries.jl
```

ADMG party:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/admg_models/party_admg.jl `
  --queries examples/queries/party_queries.jl
```

HEPAR2:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/admg_models/hepar2_bn_admg.jl `
  --queries examples/queries/hepar2_conditional_queries.jl
```

Disable trace export:

```powershell
julia --project=. src/run_demo.jl --no-trace
```

StringDiagram drug:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/string_diagrams/drug_scm.jl `
  --queries examples/queries/drug_queries.jl
```

StringDiagram party:

```powershell
julia --project=. src/run_demo.jl `
  --diagram examples/string_diagrams/party_scm.jl `
  --queries examples/queries/party_queries.jl
```
