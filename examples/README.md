# README Example

This folder contains both supported input styles for `identify_counterfactual`:

- `examples/string_diagrams/`: StringDiagram inputs (Catlab diagram definitions built with `@present`/`@program`).
- `examples/admg_models/`: ADMG inputs (`ADMGModel` or BN-imported ADMG).
- `examples/queries/`: counterfactual query sets.

It also contains causal-inference examples under `examples/causal_inference/`. These use the separate `infer_causal_effect` interface, not `identify_counterfactual`.

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
- Causal inference:
  - `causal_inference/smoking_scenario.jl`
  - `causal_inference/hepar2_comb_scenario.jl`

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

- `causal_inference/smoking_scenario.jl`
  - This example is a small health story. `S` records whether a person smokes, `T` records the tar exposure caused by smoking, and `C` records whether cancer occurs. The question is not just whether smoking and cancer are associated in the observed data. The question is what the cancer distribution would be if we actively set smoking to a chosen value: `P(C | do(S))`.
  - To run it, the user provides the smoking diagram, an observational table `P(S,T,C)`, and marks `S` as the intervention variable, `T` as the intermediate bridge, and `C` as the outcome. The tool checks that the diagram supports this calculation and returns the numerical interventional distribution.


- `causal_inference/hepar2_comb_scenario.jl`
  - This is the larger clinical example. HEPAR2 is a liver-disease network with 70 clinical variables and 123 directed edges. In this demo, we focus on one concrete pathway: hospital-related history, surgery history, and choledocholithotomy may affect injection or transfusion exposure, and those exposures may affect chronic hepatitis.
  - The question is: if we actively set the hospital/surgery/choledocholithotomy-side variables, what distribution would we get for chronic hepatitis? In the main demo this is `P(ChHepatitis | do(hospital, surgery, choledocholithotomy))`.
  - The synthetic table is used only to demonstrate and benchmark the interface; it is not the original HEPAR2 CPT parameterization. The pyAgrum comparison uses the same selected variables and checks that Julia returns the same numerical distribution.

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

- `causal_inference/smoking_scenario` variables
  - `S`: smoking status. This is the intervention variable in the query `P(C | do(S))`.
  - `T`: tar exposure level caused by smoking. This is the bridge variable between smoking and cancer.
  - `C`: cancer outcome.
  - `H`: unobserved background health or susceptibility factor used inside the string diagram. It is part of the diagrammatic structure, but it is not included in the supplied observational joint table `P(S,T,C)`.

- `causal_inference/hepar2_comb_scenario` variables
  - `hospital`: whether the patient has a hospital-related exposure or admission history. In the main demo this is an intervention variable; in some benchmark cases it is used as observed context.
  - `surgery`: whether the patient has a surgery-related history. This is an intervention variable in the main demo.
  - `choledocholithotomy`: bile-duct or gallstone-related surgical history. This variable has multiple synthetic values in the example and is an intervention variable in the main demo.
  - `injections`: injection-related exposure. This is a bridge variable.
  - `transfusion`: blood transfusion-related exposure. This is a bridge variable.
  - `ChHepatitis`: chronic hepatitis status. This is the outcome variable.

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

Causal inference smoking scenario:

```powershell
julia --project=. examples/causal_inference/smoking_scenario.jl
```

Causal inference HEPAR2 comb scenario:

```powershell
julia --project=. examples/causal_inference/hepar2_comb_scenario.jl
```

pyAgrum numerical baseline for HEPAR2 comb cases:

```powershell
python comparisons/runtime/python_pyagrum_hepar2_comb_cases_benchmark.py 30 5
python comparisons/runtime/make_hepar2_comb_table.py
```

## Causal Inference Limitations

The causal-inference examples are not counterfactual ID-CF examples. They use `infer_causal_effect`, which currently supports a comb-disintegration workflow:

- The user provides a string diagram and an observational joint probability table.
- The user provides the comb variables: observed context `A`, intervention variables `X`, bridge variables `B`, and outcome variables `C`.
- If there is no context, this reduces to the basic form `P(C | do(X))`.
- With context, the target is `P(C | A, do(X))`.
- The tool identifies the `g` region, assigns the remaining internal boxes to `f`, and checks the required comb boundaries. It uses a fast candidate first and then a complete finite search over internal box partitions if needed.
- Explicit `g_boxes` and `f_boxes` are still available as an advanced override, but they are not the default user interface.
- The joint table is used for the numerical calculation of the corresponding effect channel.

The current implementation does not yet attach stochastic matrices to each box in the string diagram. It also does not compose the diagram to derive the observational joint distribution automatically. This means the examples assume the joint table is already available and compatible with the intended model.
