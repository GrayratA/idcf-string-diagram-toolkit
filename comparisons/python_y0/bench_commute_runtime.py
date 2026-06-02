"""
Runtime comparison for the commute counterfactual example.

Default comparison:
  1) Python y0   : comparisons/python_y0/commute_example.py
  2) R cfid      : comparisons/R_cfid/commute_example.r

Optional:
  3) Julia run_demo commute case (if --with-julia is provided)

Usage:
  python comparisons/python_y0/bench_commute_runtime.py --repeats 20 --warmups 3
  python comparisons/python_y0/bench_commute_runtime.py --with-julia
"""

from __future__ import annotations

import argparse
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class BenchStats:
    median_ms: float
    mean_ms: float
    min_ms: float
    max_ms: float


def bench_command(cmd: list[str], repeats: int, warmups: int) -> BenchStats:
    for _ in range(warmups):
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

    vals_ms: list[float] = []
    for _ in range(repeats):
        t0 = time.perf_counter()
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        vals_ms.append((time.perf_counter() - t0) * 1000.0)

    return BenchStats(
        median_ms=statistics.median(vals_ms),
        mean_ms=statistics.mean(vals_ms),
        min_ms=min(vals_ms),
        max_ms=max(vals_ms),
    )


def format_stats(name: str, s: BenchStats) -> str:
    return (
        f"{name:10s} median={s.median_ms:8.2f} ms  "
        f"mean={s.mean_ms:8.2f} ms  min={s.min_ms:8.2f} ms  max={s.max_ms:8.2f} ms"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeats", type=int, default=20)
    parser.add_argument("--warmups", type=int, default=3)
    parser.add_argument("--with-julia", action="store_true")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[2]
    py = sys.executable

    y0_cmd = [py, str(repo / "comparisons" / "python_y0" / "commute_example.py")]
    r_cmd = ["Rscript", str(repo / "comparisons" / "R_cfid" / "commute_example.r")]
    julia_cmd = [
        "julia",
        "--project=.",
        str(repo / "src" / "run_demo.jl"),
        "--diagram",
        str(repo / "examples" / "admg_models" / "commute_admg.jl"),
        "--queries",
        str(repo / "examples" / "queries" / "commute_queries.jl"),
        "--no-trace",
    ]

    print(f"repeats={args.repeats} warmups={args.warmups}")
    print("note: numbers include subprocess startup overhead")
    print()

    y0_stats = bench_command(y0_cmd, repeats=args.repeats, warmups=args.warmups)
    print(format_stats("y0", y0_stats))

    r_stats = bench_command(r_cmd, repeats=args.repeats, warmups=args.warmups)
    print(format_stats("cfid(R)", r_stats))

    if args.with_julia:
        try:
            j_stats = bench_command(julia_cmd, repeats=args.repeats, warmups=args.warmups)
            print(format_stats("julia", j_stats))
        except Exception as e:  # pragma: no cover
            print(f"julia      skipped ({e})")


if __name__ == "__main__":
    main()
