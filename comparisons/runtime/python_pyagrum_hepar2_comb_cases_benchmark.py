from __future__ import annotations

import statistics
import sys
import time
from dataclasses import dataclass
from pathlib import Path
import re
from typing import Callable

import numpy as np
import pyagrum as gum
import pyagrum.causal as csl


ROOT = Path(__file__).resolve().parents[2]
HEPAR2_NET = ROOT / "net" / "hepar2.net"


@dataclass(frozen=True)
class Case:
    name: str
    context: tuple[str, ...]
    intervention: tuple[str, ...]
    bridge: tuple[str, ...]
    outcome: tuple[str, ...]


CASES = [
    Case("hospital_exposure", (), ("hospital", "surgery", "choledocholithotomy"), ("injections", "transfusion"), ("ChHepatitis",)),
    Case("hospital_exposure_context", ("hospital",), ("surgery", "choledocholithotomy"), ("injections", "transfusion"), ("ChHepatitis",)),
    Case("pbc_bilirubin", (), ("age", "sex"), ("PBC", "Hyperbilirubinemia"), ("bilirubin",)),
    Case("pbc_bilirubin_context", ("age",), ("sex",), ("PBC", "Hyperbilirubinemia"), ("bilirubin",)),
    Case("toxic_hepatitis_fatigue", (), ("hepatotoxic", "alcoholism"), ("THepatitis",), ("fatigue",)),
    Case("toxic_hepatitis_fatigue_context", ("alcoholism",), ("hepatotoxic",), ("THepatitis",), ("fatigue",)),
    Case("diabetes_steatosis", (), ("diabetes",), ("obesity",), ("Steatosis",)),
    Case("gallstone_injection", (), ("gallstones",), ("choledocholithotomy",), ("injections",)),
    Case("steatosis_cirrhosis", (), ("alcoholism", "obesity"), ("Steatosis",), ("Cirrhosis",)),
    Case("hospital_hbsag", (), ("hospital", "surgery", "choledocholithotomy"), ("injections", "transfusion"), ("hbsag",)),
    Case("hospital_hbsag_context", ("hospital",), ("surgery", "choledocholithotomy"), ("injections", "transfusion"), ("hbsag",)),
    Case("viral_hbsag", (), ("injections", "transfusion", "vh_amn"), ("ChHepatitis",), ("hbsag",)),
    Case("viral_hbsag_context", ("vh_amn",), ("injections", "transfusion"), ("ChHepatitis",), ("hbsag",)),
    Case("pbc_pressure_ruq", (), ("age", "sex"), ("PBC", "Hyperbilirubinemia"), ("pressure_ruq",)),
    Case("pbc_inr", (), ("age", "sex"), ("PBC", "Hyperbilirubinemia"), ("inr",)),
    Case("toxic_hepatitis_two_bridge", (), ("hepatotoxic", "alcoholism"), ("THepatitis", "RHepatitis"), ("fatigue",)),
    Case("liver_injury_alt", (), ("alcoholism", "obesity", "hepatotoxic"), ("Steatosis", "THepatitis", "RHepatitis"), ("alt",)),
    Case("liver_injury_alt_context", ("alcoholism",), ("obesity", "hepatotoxic"), ("Steatosis", "THepatitis", "RHepatitis"), ("alt",)),
    Case("liver_injury_ggtp", (), ("alcoholism", "obesity", "hepatotoxic"), ("Steatosis", "THepatitis", "RHepatitis"), ("ggtp",)),
]


def now_ms() -> float:
    return time.perf_counter_ns() / 1e6


def stage_summary(xs: list[float]) -> dict[str, float]:
    return {
        "min_ms": min(xs),
        "median_ms": statistics.median(xs),
        "mean_ms": statistics.mean(xs),
        "max_ms": max(xs),
    }


def values_for(var: str) -> list[str]:
    if var == "choledocholithotomy":
        return ["none", "past", "recent"]
    if var == "ChHepatitis":
        return ["none", "mild", "chronic"]
    if var == "bilirubin":
        return ["low", "normal", "high"]
    if var == "age":
        return ["young", "old"]
    return [f"{var}_0", f"{var}_1"]


def input_vars(case: Case) -> tuple[str, ...]:
    return (*case.context, *case.intervention)


def variable_order(case: Case) -> tuple[str, ...]:
    return (*input_vars(case), *case.bridge, *case.outcome)


def parse_hepar2_net(path: Path = HEPAR2_NET) -> tuple[list[str], list[tuple[str, str]]]:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"//.*?$|#.*?$|%.*?$", "", text, flags=re.M)

    nodes: list[str] = []
    seen: set[str] = set()
    for match in re.finditer(r"node\s+(\"[^\"]+\"|[^\s\{]+)\s*\{", text, flags=re.S):
        node = match.group(1).strip('"')
        if node not in seen:
            nodes.append(node)
            seen.add(node)

    edges: list[tuple[str, str]] = []
    for match in re.finditer(
        r"potential\s*\(\s*(\"[^\"]+\"|[^\s\|\)]+)\s*(?:\|\s*([^\)]*?))?\s*\)",
        text,
        flags=re.S,
    ):
        child = match.group(1).strip('"')
        raw_parents = match.group(2)
        if raw_parents is None:
            continue
        for parent in re.findall(r"\"[^\"]+\"|[^,\s]+", raw_parents.strip()):
            parent = parent.strip('"')
            if parent:
                edges.append((parent, child))

    return nodes, sorted(set(edges))


def _adjacency(edges: list[tuple[str, str]]) -> dict[str, set[str]]:
    graph: dict[str, set[str]] = {}
    for parent, child in edges:
        graph.setdefault(parent, set()).add(child)
        graph.setdefault(child, set())
    return graph


def has_directed_path(edges: list[tuple[str, str]], source: str, target: str) -> bool:
    graph = _adjacency(edges)
    stack = [source]
    seen: set[str] = set()
    while stack:
        node = stack.pop()
        if node == target:
            return True
        if node in seen:
            continue
        seen.add(node)
        stack.extend(child for child in graph.get(node, set()) if child not in seen)
    return False


def validate_case_against_hepar2(case: Case) -> tuple[list[str], list[tuple[str, str]]]:
    hepar2_nodes, hepar2_edges = parse_hepar2_net()
    node_set = set(hepar2_nodes)
    selected = set(variable_order(case))
    missing = sorted(selected - node_set)
    if missing:
        raise ValueError(f"case {case.name} contains variables not present in HEPAR2: {missing}")

    return hepar2_nodes, hepar2_edges


def hepar2_path_count(case: Case, edges: list[tuple[str, str]]) -> int:
    count = 0
    for a in input_vars(case):
        for b in case.bridge:
            count += int(has_directed_path(edges, a, b))
    for b in case.bridge:
        for c in case.outcome:
            count += int(has_directed_path(edges, b, c))
    return count


def dims_for(case: Case) -> tuple[int, ...]:
    return tuple(len(values_for(v)) for v in variable_order(case))


def synthetic_joint(case: Case) -> np.ndarray:
    dims = dims_for(case)
    probs = np.zeros(dims, dtype=float)
    n_a = len(input_vars(case))
    n_b = len(case.bridge)
    a_dims = dims[:n_a]
    b_dims = dims[n_a : n_a + n_b]
    c_dims = dims[n_a + n_b :]

    for idx in np.ndindex(dims):
        vals = tuple(i for i in idx)
        a_vals = vals[:n_a]
        b_vals = vals[n_a : n_a + n_b]
        c_vals = vals[n_a + n_b :]

        p_a = 1.0
        for i, a in enumerate(a_vals):
            weights = np.array([1.0 + 0.25 * (i + 1) + 0.17 * k for k in range(a_dims[i])])
            p_a *= weights[a] / weights.sum()

        a_score = sum((i + 1) * a_vals[i] for i in range(n_a))
        p_b = 1.0
        for j, b in enumerate(b_vals):
            weights = np.array([1.0 + 0.20 * (j + 1) + 0.11 * a_score + 0.31 * k for k in range(b_dims[j])])
            p_b *= weights[b] / weights.sum()

        b_score = sum((j + 2) * b_vals[j] for j in range(n_b))
        p_c = 1.0
        for k, c_val in enumerate(c_vals):
            c_weights = np.array(
                [1.0 + 0.29 * b_score + 0.19 * (k + 1) + 0.37 * v for v in range(c_dims[k])]
            )
            p_c *= c_weights[c_val] / c_weights.sum()

        probs[idx] = p_a * p_b * p_c

    probs /= probs.sum()
    return probs


def conditional_from_joint(
    probs: np.ndarray,
    var_axis: int,
    parent_axes: tuple[int, ...],
    parent_values: tuple[int, ...],
) -> np.ndarray:
    var_dim = probs.shape[var_axis]
    dist = np.zeros(var_dim, dtype=float)
    for value in range(var_dim):
        selector = [slice(None)] * probs.ndim
        selector[var_axis] = value
        for axis, parent_value in zip(parent_axes, parent_values):
            selector[axis] = parent_value
        dist[value] = probs[tuple(selector)].sum()

    total = dist.sum()
    if total <= 0.0:
        raise ValueError(f"zero-probability parent assignment: axis={var_axis}, parents={parent_values}")
    return dist / total


def fill_cpt_from_joint(
    bn: gum.BayesNet,
    probs: np.ndarray,
    names: tuple[str, ...],
    var: str,
    selected_parents: tuple[str, ...],
) -> None:
    var_axis = names.index(var)
    selected_parent_axes = tuple(names.index(parent) for parent in selected_parents)
    cpt = bn.cpt(var)
    cpt_parents = tuple(name for name in cpt.names if name != var)

    if not cpt_parents:
        cpt.fillWith(conditional_from_joint(probs, var_axis, selected_parent_axes, ()))
        return

    cpt_parent_dims = tuple(bn.variable(parent).domainSize() for parent in cpt_parents)
    for cpt_parent_values in np.ndindex(cpt_parent_dims):
        assignment = dict(zip(cpt_parents, cpt_parent_values))
        selected_parent_values = tuple(assignment[parent] for parent in selected_parents)
        cpt[assignment] = conditional_from_joint(
            probs,
            var_axis,
            selected_parent_axes,
            selected_parent_values,
        )


def build_observational_bn(case: Case, probs: np.ndarray) -> gum.BayesNet:
    selected_names = variable_order(case)
    hepar2_nodes, hepar2_edges = validate_case_against_hepar2(case)

    bn = gum.BayesNet(case.name)
    for name in selected_names:
        bn.add(gum.LabelizedVariable(name, name, len(values_for(name))))

    def safe_add_arc(parent: str, child: str) -> None:
        if parent == child or bn.existsArc(parent, child):
            return
        bn.addArc(parent, child)

    # Build the reduced comb graph from the A/B/C witness validated by the
    # Julia full-diagram proof. The HEPAR2 file is imported above to validate
    # that these selected variables come from the source model; the reduced
    # pyAgrum baseline then runs on the extracted query-level comb graph.
    inputs = input_vars(case)
    for i, child in enumerate(inputs):
        for parent in inputs[:i]:
            safe_add_arc(parent, child)

    for a in inputs:
        for b in case.bridge:
            safe_add_arc(a, b)
    for b in case.bridge:
        for c in case.outcome:
            safe_add_arc(b, c)

    # pyAgrum represents latent confounding by adding latent descriptors to a
    # standard observational BN. These arcs are observational parameterization
    # arcs only; `CausalModel(..., keepArcs=false)` removes them and replaces
    # them with latent variables in the causal graph.
    for a in inputs:
        for c in case.outcome:
            safe_add_arc(a, c)

    for var in selected_names:
        parents = tuple(bn.cpt(var).names[1:])
        fill_cpt_from_joint(bn, probs, selected_names, var, parents)

    return bn


def fill_uniform_cpt(bn: gum.BayesNet, var: str) -> None:
    cpt = bn.cpt(var)
    parents = tuple(cpt.names[1:])
    dist = np.ones(bn.variable(var).domainSize(), dtype=float)
    dist /= dist.sum()

    if not parents:
        cpt.fillWith(dist)
        return

    parent_dims = tuple(bn.variable(parent).domainSize() for parent in parents)
    for parent_values in np.ndindex(parent_dims):
        cpt[dict(zip(parents, parent_values))] = dist


def build_causal_model(case: Case, bn: gum.BayesNet) -> csl.CausalModel:
    latent = []
    for a in input_vars(case):
        for c in case.outcome:
            latent.append((f"U_{a}_{c}", (a, c)))
    return csl.CausalModel(bn, latent, keepArcs=False)


def tensor_vector_in_julia_order(case: Case, tensor: gum.Tensor) -> np.ndarray:
    arr = np.asarray(tensor.toarray(), dtype=float)
    # pyAgrum reports tensor names in display order, while `toarray()` exposes
    # the reverse axis order. Reorder by variable name before flattening with
    # Julia's column-major convention.
    names = tuple(reversed(tuple(tensor.names)))
    target_axes = tuple(case.outcome) + tuple(case.context) + tuple(case.intervention)
    missing = [name for name in target_axes if name not in names]
    if missing:
        raise ValueError(f"pyAgrum tensor is missing expected axes: {missing}; got {tuple(tensor.names)}")
    extra_axes = tuple(name for name in names if name not in target_axes)
    arr = np.transpose(arr, [names.index(name) for name in (*target_axes, *extra_axes)])
    if extra_axes:
        arr = arr.mean(axis=tuple(range(len(target_axes), arr.ndim)))
    return arr.ravel(order="F")


def run_case(case: Case) -> dict[str, object]:
    total_t0 = now_ms()

    setup_t0 = now_ms()
    probs = synthetic_joint(case)
    bn = build_observational_bn(case, probs)
    cm = build_causal_model(case, bn)
    hepar2_nodes, hepar2_edges = parse_hepar2_net()
    path_count = hepar2_path_count(case, hepar2_edges)
    setup_ms = now_ms() - setup_t0

    impact_t0 = now_ms()
    on = case.outcome[0] if len(case.outcome) == 1 else set(case.outcome)
    knowing = set(case.context) if case.context else None
    _formula, tensor, explanation = csl.causalImpact(
        cm,
        on=on,
        doing=set(case.intervention),
        knowing=knowing,
    )
    impact_ms = now_ms() - impact_t0

    effect_vector = tensor_vector_in_julia_order(case, tensor)
    total_ms = now_ms() - total_t0
    return {
        "setup_ms": setup_ms,
        "impact_ms": impact_ms,
        "total_ms": total_ms,
        "hepar2_node_count": len(hepar2_nodes),
        "hepar2_edge_count": len(hepar2_edges),
        "hepar2_path_count": path_count,
        "bn_arc_count": len(list(bn.arcs())),
        "reduced_node_count": len(bn.names()),
        "effect_checksum": float(effect_vector.sum()),
        "first_effect": float(effect_vector[0]),
        "effect_values": ",".join(f"{x:.12g}" for x in effect_vector),
        "explanation": explanation.replace("\n", " "),
    }


def benchmark_stages(f: Callable[[], dict[str, object]], repeats: int, warmups: int) -> dict[str, object]:
    for _ in range(warmups):
        f()

    cold = f()
    samples = {k: [] for k in ["setup_ms", "impact_ms", "total_ms"]}
    last = cold

    for _ in range(repeats):
        cur = f()
        for k in samples:
            samples[k].append(float(cur[k]))
        last = cur

    return {
        "cold": cold,
        "warm": {k: stage_summary(v) for k, v in samples.items()},
        "result": last,
    }


def print_summary(case: Case, stats: dict[str, object]) -> None:
    warm = stats["warm"]
    result = stats["result"]
    assert isinstance(warm, dict)
    assert isinstance(result, dict)

    print(
        "impl=python_pyagrum_causal "
        f"example={case.name} "
        f"warm_total_median_ms={warm['total_ms']['median_ms']:.3f} "
        f"warm_setup_median_ms={warm['setup_ms']['median_ms']:.3f} "
        f"warm_impact_median_ms={warm['impact_ms']['median_ms']:.3f} "
        f"hepar2_node_count={int(result['hepar2_node_count'])} "
        f"hepar2_edge_count={int(result['hepar2_edge_count'])} "
        f"hepar2_path_count={int(result['hepar2_path_count'])} "
        f"bn_arc_count={int(result['bn_arc_count'])} "
        f"reduced_node_count={int(result['reduced_node_count'])} "
        f"context_count={len(case.context)} "
        f"intervention_count={len(case.intervention)} "
        f"bridge_count={len(case.bridge)} "
        f"outcome_count={len(case.outcome)} "
        f"effect_checksum={float(result['effect_checksum']):.6f} "
        f"first_effect={float(result['first_effect']):.6f} "
        f"effect_values={result['effect_values']}"
    )
    print(f"explanation={result['explanation']}")


def main(argv: list[str]) -> None:
    repeats = int(argv[1]) if len(argv) >= 2 else 30
    warmups = int(argv[2]) if len(argv) >= 3 else 5
    case_filter = set(argv[3].split(",")) if len(argv) >= 4 else None
    print(f"impl=python_pyagrum_causal benchmark_config repeats={repeats} warmups={warmups} timer=perf_counter_ns")
    for case in CASES:
        if case_filter is not None and case.name not in case_filter:
            continue
        print_summary(case, benchmark_stages(lambda case=case: run_case(case), repeats, warmups))


if __name__ == "__main__":
    main(sys.argv)

