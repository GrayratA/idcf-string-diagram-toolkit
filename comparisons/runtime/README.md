# README Runtime

Runtime comparison scripts for the Julia prototype and R `cfid`.

These benchmarks measure in-process runtime after startup.
They report:

- `cold_total_ms`: first full call in a fresh process
- `warm_total_min_ms`, `warm_total_median_ms`, `warm_total_mean_ms`, `warm_total_max_ms`: repeated full-call timings in the same process
- Stage medians for warm runs:
  - Julia: `warm_setup_median_ms`, `warm_identify_median_ms`, `warm_build_median_ms`, `warm_simplify_median_ms`, `warm_step4_median_ms`, `warm_step5_median_ms`
  - R `cfid`: `warm_setup_median_ms`, `warm_identifiable_median_ms` and alias `warm_identify_median_ms`

Example usage:

```powershell
julia --project=. comparisons/runtime/julia_benchmark.jl 30 5
Rscript comparisons/runtime/r_cfid_benchmark.R 30 5
python comparisons/runtime/python_y0_benchmark.py 30 5
```

Causal-inference / comb-disintegration benchmark:

```powershell
julia --project=. comparisons/runtime/julia_hepar2_comb_cases_benchmark.jl 30 5
python comparisons/runtime/python_pyagrum_hepar2_comb_cases_benchmark.py 30 5
python comparisons/runtime/make_hepar2_comb_table.py
```

The current scripts benchmark three examples:

- `drug`
- `party`
- `hepar2_conditional`

`python_y0_benchmark.py` currently benchmarks:

- `drug`
- `party`
- `commute`
- `hepar2_conditional` (via a binary-event mapping of the conditional counterfactual query)

The causal-inference benchmark scripts currently benchmark multiple HEPAR2-selected comb queries, including both `P(C | do(A))` and context-aware `P(C | context, do(intervention))` cases. The numerical baseline is reduced pyAgrum `causalImpact`, not y0. The processed comparison table is:

- `comparisons/runtime/hepar2_comb_pyagrum_reduced_runtime_by_complexity.csv`

Notes on alignment:

- Both implementations include all preprocessing done inside each script's run function in `total`.
- For `party`, Julia uses `data_mode=:none` and R `cfid` omits the `data` argument to avoid a data-mode mismatch.
- For HEPAR2 comb cases, Julia measures `setup`, full Catlab comb `proof`, and finite comb computation. The computation stage uses the direct fast path and skips the optional reconstruction diagnostic.
- The pyAgrum baseline parses the real HEPAR2 structure from `net/hepar2.net` (`70` nodes and `123` directed edges), verifies that the selected comb variables come from that model, and then runs `causalImpact` on the extracted reduced query-level comb graph.
- The synthetic joint table is used only for the selected comb variables, so both implementations evaluate the same finite selected-query distribution rather than the original HEPAR2 CPT parameters.

## Structural Tests

Structural-scaling and profiling artifacts are under:

- `comparisons/runtime/structural_tests/scripts`: runnable scripts
- `comparisons/runtime/structural_tests/raw`: raw text outputs
- `comparisons/runtime/structural_tests/processed`: generated CSV tables
- `comparisons/runtime/structural_tests/profiles`: Rprof output files

Example usage:

```powershell
julia comparisons/runtime/structural_tests/scripts/struct_scaling_julia.jl 4 2 8,16,24,32 | Tee-Object -FilePath comparisons/runtime/structural_tests/raw/struct_julia_r4w2.txt
```

```powershell
Rscript comparisons/runtime/structural_tests/scripts/struct_scaling_r.R 4 2 8,16,24,32 | Tee-Object -FilePath comparisons/runtime/structural_tests/raw/struct_r_r4w2.txt
```

```powershell
python comparisons/runtime/structural_tests/scripts/struct_scaling_y0.py 4 2 8,16,24,32 | Tee-Object -FilePath comparisons/runtime/structural_tests/raw/struct_y0_r4w2.txt
```

```powershell
pwsh -File comparisons/runtime/structural_tests/scripts/make_struct_csv.ps1 -Tag r4w2
```
