"""Minimal y0 check for the dense4 counterfactual query.

Graph:
    V1 -> V2 -> V4

Julia query being mirrored:
    CounterfactualQuery(:T1, Dict(:V1 => :v1), Dict(), [:V4])
    CounterfactualQuery(:Real, Dict(), Dict(:V2 => :v2), [])

Distribution-level meaning:
    P(V4_{do(V1=v1)} | V2 = v2)

y0's public counterfactual API is binary-event based, so this script checks both
output events:
    P(V4_{do(V1=+)} = + | V2 = +)
    P(V4_{do(V1=+)} = - | V2 = +)

Run:
    python comparisons/python_y0/dense4_check.py
"""

from __future__ import annotations

from y0.algorithm.identify.idc_star import idc_star
from y0.algorithm.identify.utils import Unidentifiable
from y0.dsl import Variable
from y0.graph import NxMixedGraph


def run_query(graph: NxMixedGraph, label: str, outcomes: dict, conditions: dict) -> None:
    print(label)
    try:
        expr = idc_star(graph, outcomes=outcomes, conditions=conditions)
    except (Unidentifiable, ValueError) as e:
        print("identifiable = False")
        print("error =", repr(e))
        print()
        return

    print("identifiable = True")
    print("formula text =", expr.to_text())
    print("formula y0   =", expr.to_y0())
    print("formula latex=", expr.to_latex())
    print()


def main() -> None:
    v1 = Variable("V1")
    v2 = Variable("V2")
    v4 = Variable("V4")

    graph = NxMixedGraph.from_edges(
        directed=[
            (v1, v2),
            (v2, v4),
        ],
        undirected=[],
    )

    conditions = {
        v2: +v2,
    }

    print("== dense4 y0 check ==")
    print("Graph: V1 -> V2 -> V4")
    print("Julia-equivalent distribution query: P(V4_{do(V1=v1)} | V2 = v2)")
    print("Binary y0 encoding: v1 -> +V1, v2 -> +V2")
    print()

    run_query(
        graph,
        "Event 1: P(V4_{do(V1=+)} = + | V2 = +)",
        outcomes={(v4 @ +v1): +v4},
        conditions=conditions,
    )
    run_query(
        graph,
        "Event 2: P(V4_{do(V1=+)} = - | V2 = +)",
        outcomes={(v4 @ +v1): -v4},
        conditions=conditions,
    )


if __name__ == "__main__":
    main()
