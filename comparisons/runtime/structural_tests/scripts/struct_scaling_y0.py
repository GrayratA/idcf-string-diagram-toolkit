from __future__ import annotations

import statistics
import sys
import time
from typing import Callable

from y0.algorithm.identify.idc_star import idc_star
from y0.algorithm.identify.utils import Unidentifiable
from y0.dsl import Variable
from y0.graph import NxMixedGraph


def now_ms() -> float:
    return time.perf_counter_ns() / 1e6


def stage_summary(xs: list[float]) -> dict[str, float]:
    return {
        "min_ms": min(xs),
        "median_ms": statistics.median(xs),
        "mean_ms": statistics.mean(xs),
        "max_ms": max(xs),
    }


def v(i: int) -> Variable:
    return Variable(f"V{i}")


def edges_chain(n: int) -> list[tuple[Variable, Variable]]:
    return [(v(i), v(i + 1)) for i in range(1, n)]


def edges_fanin(n: int) -> list[tuple[Variable, Variable]]:
    out: list[tuple[Variable, Variable]] = []
    for i in range(2, n):
        out.append((v(1), v(i)))
        out.append((v(i), v(n)))
    out.append((v(1), v(n)))
    # preserve insertion order while removing duplicates
    return list(dict.fromkeys(out))


def edges_chain_bi(n: int) -> tuple[list[tuple[Variable, Variable]], list[tuple[Variable, Variable]]]:
    directed = edges_chain(n)
    undirected = [(v(i), v(i + 1)) for i in range(1, n)]
    return directed, undirected


def edges_dense(n: int) -> list[tuple[Variable, Variable]]:
    out = edges_chain(n)
    for i in range(1, n):
        for j in range(i + 1, n + 1):
            if ((i * 37 + j * 17) % 10) < 3:
                out.append((v(i), v(j)))
    return list(dict.fromkeys(out))


def make_graph(family: str, n: int) -> NxMixedGraph:
    if family == "chain":
        return NxMixedGraph.from_edges(directed=edges_chain(n), undirected=[])
    if family == "fanin":
        return NxMixedGraph.from_edges(directed=edges_fanin(n), undirected=[])
    if family == "dense":
        return NxMixedGraph.from_edges(directed=edges_dense(n), undirected=[])
    if family == "chain_bi":
        directed, undirected = edges_chain_bi(n)
        return NxMixedGraph.from_edges(directed=directed, undirected=undirected)
    raise ValueError(f"unknown family: {family}")


def run_case(graph: NxMixedGraph, treat: Variable, out: Variable) -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    outcomes = {(out @ +treat): +out}
    conditions = {treat: +treat}
    setup_ms = now_ms() - setup_t0

    ident_t0 = now_ms()
    ok = True
    try:
        _ = idc_star(graph, outcomes=outcomes, conditions=conditions)
    except (Unidentifiable, ValueError):
        ok = False
    identify_ms = now_ms() - ident_t0

    total_ms = now_ms() - total_t0
    return {
        "ok": ok,
        "setup_ms": setup_ms,
        "identify_ms": identify_ms,
        "total_ms": total_ms,
    }


def benchmark_case(f: Callable[[], dict[str, object]], repeats: int, warmups: int) -> dict[str, object]:
    for _ in range(warmups):
        f()

    cold = f()
    samples_setup: list[float] = []
    samples_ident: list[float] = []
    samples_total: list[float] = []
    last = cold

    for _ in range(repeats):
        cur = f()
        samples_setup.append(float(cur["setup_ms"]))
        samples_ident.append(float(cur["identify_ms"]))
        samples_total.append(float(cur["total_ms"]))
        last = cur

    return {
        "cold": cold,
        "warm": {
            "setup_ms": stage_summary(samples_setup),
            "identify_ms": stage_summary(samples_ident),
            "total_ms": stage_summary(samples_total),
        },
        "last": last,
    }


def run_family(family: str, n: int, repeats: int, warmups: int) -> None:
    treat = v(1)
    out = v(n)
    graph = make_graph(family, n)
    stats = benchmark_case(lambda: run_case(graph, treat, out), repeats=repeats, warmups=warmups)
    w = stats["warm"]
    print(
        "impl=python_y0_struct "
        f"family={family} "
        f"n={n} "
        f"ok={stats['last']['ok']} "
        f"warm_total_median_ms={w['total_ms']['median_ms']:.3f} "
        f"warm_setup_median_ms={w['setup_ms']['median_ms']:.3f} "
        f"warm_identify_median_ms={w['identify_ms']['median_ms']:.3f}"
    )


def main(argv: list[str]) -> int:
    repeats = int(argv[1]) if len(argv) >= 2 else 7
    warmups = int(argv[2]) if len(argv) >= 3 else 3
    ns = [int(x) for x in argv[3].split(",")] if len(argv) >= 4 else [8, 16, 24, 32]

    print(f"impl=python_y0_struct benchmark_config repeats={repeats} warmups={warmups} timer=perf_counter_ns")
    for family in ("chain", "fanin", "dense", "chain_bi"):
        for n in ns:
            run_family(family, n, repeats=repeats, warmups=warmups)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
