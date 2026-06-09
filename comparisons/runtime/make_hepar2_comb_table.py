from __future__ import annotations

import csv
import re
from pathlib import Path

from python_pyagrum_hepar2_comb_cases_benchmark import CASES, dims_for, input_vars


ROOT = Path(__file__).resolve().parent
JULIA_RAW = ROOT / "raw_julia_hepar2_comb_cases.txt"
PYAGRUM_RAW = ROOT / "raw_python_pyagrum_hepar2_comb_cases.txt"
OUT_CSV = ROOT / "hepar2_comb_pyagrum_reduced_runtime_by_complexity.csv"


def parse_key_values(path: Path) -> dict[str, dict[str, str]]:
    records: dict[str, dict[str, str]] = {}
    pattern = re.compile(r"(\w+)=([^\s]+)")
    for line in path.read_text(encoding="utf-8").splitlines():
        if " example=" not in line:
            continue
        fields = dict(pattern.findall(line))
        example = fields.get("example")
        if example:
            records[example] = fields
    return records


def join_vars(xs: tuple[str, ...]) -> str:
    return "; ".join(xs)


def as_float(fields: dict[str, str], key: str) -> float:
    return float(fields[key])


def as_int(fields: dict[str, str], key: str) -> int:
    return int(fields[key])


def parse_vector(fields: dict[str, str]) -> list[float]:
    return [float(x) for x in fields["effect_values"].split(",") if x]


def main() -> None:
    julia = parse_key_values(JULIA_RAW)
    pyagrum = parse_key_values(PYAGRUM_RAW)

    rows = []
    for case in CASES:
        if case.name not in julia or case.name not in pyagrum:
            continue

        jr = julia[case.name]
        pr = pyagrum[case.name]
        input_count = len(input_vars(case))
        state_space_size = 1
        for dim in dims_for(case):
            state_space_size *= dim

        julia_ms = as_float(jr, "warm_total_median_ms")
        pyagrum_ms = as_float(pr, "warm_total_median_ms")
        ratio = pyagrum_ms / julia_ms

        julia_vec = parse_vector(jr)
        pyagrum_vec = parse_vector(pr)
        if len(julia_vec) != len(pyagrum_vec):
            max_abs_diff = float("inf")
        else:
            max_abs_diff = max(abs(a - b) for a, b in zip(julia_vec, pyagrum_vec))
        full_effect_match = max_abs_diff < 1e-9

        rows.append(
            {
                "Case": case.name,
                "Context": join_vars(case.context),
                "Interventions": join_vars(case.intervention),
                "Bridge": join_vars(case.bridge),
                "Outcome": join_vars(case.outcome),
                "Comb variable count": input_count + len(case.bridge) + len(case.outcome),
                "pyAgrum reduced nodes": as_int(pr, "reduced_node_count"),
                "Julia warm median ms": round(julia_ms, 3),
                "pyAgrum warm median ms": round(pyagrum_ms, 3),
                "pyAgrum / Julia": round(ratio, 2),
                "Faster implementation": "Julia" if ratio > 1 else "pyAgrum",
                "Max abs diff": f"{max_abs_diff:.3e}",
                "Full effect match": full_effect_match,
            }
        )

    rows.sort(key=lambda r: (r["Comb variable count"], r["Case"]))

    with OUT_CSV.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {OUT_CSV} ({len(rows)} rows)")


if __name__ == "__main__":
    main()

