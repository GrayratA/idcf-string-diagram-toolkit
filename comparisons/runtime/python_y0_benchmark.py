from __future__ import annotations

import statistics
import sys
import time
from pathlib import Path
from typing import Callable

from y0.dsl import Variable
from y0.graph import NxMixedGraph

try:
    from y0.algorithm.identify.idc_star import idc_star
    from y0.algorithm.identify.utils import Unidentifiable
except ImportError as e:  # pragma: no cover
    raise RuntimeError("Cannot import y0 IDC* APIs. Install y0 first: pip install y0") from e


def now_ms() -> float:
    return time.perf_counter_ns() / 1e6


def stage_summary(xs: list[float]) -> dict[str, float]:
    return {
        "min_ms": min(xs),
        "median_ms": statistics.median(xs),
        "mean_ms": statistics.mean(xs),
        "max_ms": max(xs),
    }


def benchmark_stages(f: Callable[[], dict[str, object]], repeats: int = 30, warmups: int = 5) -> dict[str, object]:
    for _ in range(warmups):
        f()

    cold = f()
    samples_setup: list[float] = []
    samples_ident: list[float] = []
    samples_total: list[float] = []
    last_res = cold

    for _ in range(repeats):
        cur = f()
        samples_setup.append(float(cur["setup_ms"]))
        samples_ident.append(float(cur["identify_ms"]))
        samples_total.append(float(cur["total_ms"]))
        last_res = cur

    return {
        "cold": cold,
        "warm": {
            "setup_ms": stage_summary(samples_setup),
            "identify_ms": stage_summary(samples_ident),
            "total_ms": stage_summary(samples_total),
        },
        "result": last_res,
    }


def _run_idc(graph: NxMixedGraph, outcomes: dict, conditions: dict) -> tuple[bool, str]:
    try:
        expr = idc_star(graph, outcomes=outcomes, conditions=conditions)
        return True, expr.to_y0()
    except (Unidentifiable, ValueError) as e:
        return False, f"FAIL: {e!r}"


def parse_hepar2_dag(path: Path) -> NxMixedGraph:
    directed: list[tuple[Variable, Variable]] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("//", 1)[0].split("#", 1)[0].strip()
        if not line.startswith("potential"):
            continue
        # Matches:
        # potential (child)
        # potential (child | parent1 parent2 ...)
        if "(" not in line or ")" not in line:
            continue
        inside = line[line.find("(") + 1 : line.rfind(")")]
        if "|" not in inside:
            continue
        child_part, parents_part = inside.split("|", 1)
        child = child_part.strip().lower()
        parents = [p.lower() for p in parents_part.strip().split() if p]
        for p in parents:
            directed.append((Variable(p), Variable(child)))
    return NxMixedGraph.from_edges(directed=directed, undirected=[])


def run_drug_example() -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    X, W, D, Z, Y = map(Variable, ["X", "W", "D", "Z", "Y"])
    g = NxMixedGraph.from_edges(
        directed=[(X, W), (W, Y), (D, Z), (Z, Y)],
        undirected=[(X, Y)],
    )
    outcomes = {(Y @ +X): +Y}
    conditions = {X: -X, D: +D, (Z @ +D): +Z}
    setup_ms = now_ms() - setup_t0

    ident_t0 = now_ms()
    ok, formula = _run_idc(g, outcomes, conditions)
    identify_ms = now_ms() - ident_t0

    total_ms = now_ms() - total_t0
    return {
        "setup_ms": setup_ms,
        "identify_ms": identify_ms,
        "total_ms": total_ms,
        "output_ok": ok,
        "formula": formula,
    }


def run_party_example() -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    A, B, C, S = map(Variable, ["A", "B", "C", "S"])
    g = NxMixedGraph.from_edges(
        directed=[(A, B), (A, C), (B, S), (C, S)],
        undirected=[],
    )
    outcomes = {(S @ +B): +S}
    conditions = {B: -B}
    setup_ms = now_ms() - setup_t0

    ident_t0 = now_ms()
    ok, formula = _run_idc(g, outcomes, conditions)
    identify_ms = now_ms() - ident_t0

    total_ms = now_ms() - total_t0
    return {
        "setup_ms": setup_ms,
        "identify_ms": identify_ms,
        "total_ms": total_ms,
        "output_ok": ok,
        "formula": formula,
    }


def run_commute_example() -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    W, T, M, L, Y = map(Variable, ["W", "T", "M", "L", "Y"])
    g = NxMixedGraph.from_edges(
        directed=[(W, T), (W, M), (T, L), (M, L), (L, Y)],
        undirected=[(T, Y)],
    )
    outcomes = {(Y @ +T): +Y}
    conditions = {W: +W, T: -T, (M @ +W): +M}
    setup_ms = now_ms() - setup_t0

    ident_t0 = now_ms()
    ok, formula = _run_idc(g, outcomes, conditions)
    identify_ms = now_ms() - ident_t0

    total_ms = now_ms() - total_t0
    return {
        "setup_ms": setup_ms,
        "identify_ms": identify_ms,
        "total_ms": total_ms,
        "output_ok": ok,
        "formula": formula,
    }


def run_hepar2_conditional_example() -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    repo = Path(__file__).resolve().parents[2]
    g = parse_hepar2_dag(repo / "net" / "hepar2.net")

    age = Variable("age")
    sex = Variable("sex")
    pbc = Variable("pbc")
    carcinoma = Variable("carcinoma")

    # Binary-event mapping of:
    # P(carcinoma_{do(age)} | age, sex, pbc_{do(age)})
    outcomes = {(carcinoma @ +age): +carcinoma}
    conditions = {
        age: +age,
        sex: +sex,
        (pbc @ +age): +pbc,
    }
    setup_ms = now_ms() - setup_t0

    ident_t0 = now_ms()
    ok, formula = _run_idc(g, outcomes, conditions)
    identify_ms = now_ms() - ident_t0

    total_ms = now_ms() - total_t0
    return {
        "setup_ms": setup_ms,
        "identify_ms": identify_ms,
        "total_ms": total_ms,
        "output_ok": ok,
        "formula": formula,
    }


def print_summary(label: str, stats: dict[str, object]) -> None:
    cold = stats["cold"]
    warm = stats["warm"]
    assert isinstance(cold, dict)
    assert isinstance(warm, dict)

    total = warm["total_ms"]
    setup = warm["setup_ms"]
    ident = warm["identify_ms"]
    assert isinstance(total, dict) and isinstance(setup, dict) and isinstance(ident, dict)

    print(
        "impl=python_y0 "
        f"example={label} "
        f"cold_total_ms={float(cold['total_ms']):.3f} "
        f"warm_total_min_ms={total['min_ms']:.3f} "
        f"warm_total_median_ms={total['median_ms']:.3f} "
        f"warm_total_mean_ms={total['mean_ms']:.3f} "
        f"warm_total_max_ms={total['max_ms']:.3f} "
        f"warm_setup_median_ms={setup['median_ms']:.3f} "
        f"warm_identifiable_median_ms={ident['median_ms']:.3f}"
    )
    print(f"impl=python_y0 alias example={label} warm_identify_median_ms={ident['median_ms']:.3f}")

    res = stats["result"]
    assert isinstance(res, dict)
    formula = str(res.get("formula", "FAIL"))
    if bool(res.get("output_ok", False)):
        print(f"formula={formula}")
    else:
        print("formula=FAIL")


def main(argv: list[str]) -> None:
    repeats = int(argv[1]) if len(argv) >= 2 else 30
    warmups = int(argv[2]) if len(argv) >= 3 else 5

    print(f"impl=python_y0 benchmark_config repeats={repeats} warmups={warmups} timer=perf_counter_ns")
    print_summary("drug", benchmark_stages(run_drug_example, repeats=repeats, warmups=warmups))
    print_summary("party", benchmark_stages(run_party_example, repeats=repeats, warmups=warmups))
    print_summary("commute", benchmark_stages(run_commute_example, repeats=repeats, warmups=warmups))
    print_summary(
        "hepar2_conditional",
        benchmark_stages(run_hepar2_conditional_example, repeats=repeats, warmups=warmups),
    )


if __name__ == "__main__":
    main(sys.argv)
