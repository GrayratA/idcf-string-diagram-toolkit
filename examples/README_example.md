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
  - This scenario models a daily commuting setting with variables `O = {W, T, M, L, Y}`: weather (`W`), departure time (`T`), mode of transport (`M`), lateness (`L`), and final work performance (`Y`).
  - The directed causal links are `W -> T`, `W -> M`, `T -> L`, `M -> L`, and `L -> Y`, with a bidirected edge `T <-> Y` representing latent confounding between departure time and final outcome.
  - The counterfactual target in this example is the probability of `Y(1)` under an intervention `do(T(1)=t)`, while conditioning on evidence that in the factual world `W(2)=w` and `T(2)=t'`, and in an auxiliary world with `do(W(3)=w)` we observe `M(3)=m`.
  - In plain terms: for someone who actually left at time `t'` on weather condition `w`, what would their work performance have been if they had left at time `t`, while also incorporating additional behavioral evidence that under the same weather they would use transport mode `m`?

- `drug` (`drug_admg.jl` / `drug_scm.jl` + `drug_queries.jl`)
  - Imagine a patient treated with two drugs. Drug `X` and drug `D` both influence the final symptom `Y`, and `D` also affects an intermediate marker `Z` that doctors can observe. There is another pathway through `W`, so outcome changes are not explained by one variable alone.
  - You have mixed evidence from different clinical contexts: in one context you want to evaluate what would happen under dose `x` for drug `X`; in another you know the patient actually had dose `x~` for `X` and dose `d` for `D`; in another you know that under dose `d`, marker `Z` was observed as `z`.
  - The question is: after combining all that evidence, how likely is symptom `Y` under the hypothetical treatment choice? This is useful because it mirrors real decision-making, where doctors combine observed records with "what-if" treatment alternatives instead of relying on a single intervention view.

- `party` (`party_admg.jl` / `party_scm.jl` + `party_queries.jl`)
  - This is the classic Ann-Bob-Carl party story. Ann’s attendance (`A`) influences whether Bob (`B`) and Carl (`C`) go, and the chance of a scuffle (`S`) depends strongly on whether Bob and Carl are both there. In the observed event, Bob did not attend, but the counterfactual asks what would likely have happened if he had gone, while keeping the rest of the situation aligned with the same night. It is a natural "alternate history" question that makes counterfactual reasoning intuitive.

- `hepar2` (`hepar2_bn_admg.jl` + `hepar2_conditional_queries.jl`)
  - The HEPAR2 case moves from toy examples to a realistic medical network. For a patient with observed evidence such as `age`, `sex`, and `pbc`, we ask about the likelihood of `carcinoma` under a hypothetical age-related intervention, while preserving the rest of the observed context. This example shows that the same workflow used for small didactic stories can still operate on large clinical graphs with many background variables.

## Variable Glossary

- `commute` variables
  - `W`: weather condition.
  - `T`: departure time.
  - `M`: mode of transport.
  - `L`: lateness.
  - `Y`: final work performance.
  - `R1`: latent shared disturbance creating unobserved dependence between `T` and `Y` in the ADMG/string-diagram construction.


- `drug` variables
  - `X`: dose/intensity variable for drug `X` (appears in both intervention and observed-world constraints).
  - `D`: dose/intensity variable for drug `D`.
  - `Z`: intermediate symptom/marker that responds to treatment `D`.
  - `W`: additional intermediate pathway variable downstream of `X`.
  - `Y`: target symptom/outcome queried counterfactually.

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
julia --project=. src/run_demo.jl --diagram examples/admg_models/commute_admg.jl --queries examples/queries/commute_queries.jl
```

ADMG drug:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/drug_admg.jl --queries examples/queries/drug_queries.jl
```

ADMG party:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/party_admg.jl --queries examples/queries/party_queries.jl
```

HEPAR2:

```powershell
julia --project=. src/run_demo.jl --diagram examples/admg_models/hepar2_bn_admg.jl --queries examples/queries/hepar2_conditional_queries.jl
```

Disable trace export:

```powershell
julia --project=. src/run_demo.jl --no-trace
```

StringDiagram drug:

```powershell
julia --project=. src/run_demo.jl --diagram examples/string_diagrams/drug_scm.jl --queries examples/queries/drug_queries.jl
```

StringDiagram party:

```powershell
julia --project=. src/run_demo.jl --diagram examples/string_diagrams/party_scm.jl --queries examples/queries/party_queries.jl
```
