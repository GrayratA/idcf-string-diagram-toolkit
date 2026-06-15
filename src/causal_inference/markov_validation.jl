"""
Optional Markov-property validation for finite-discrete DAG inputs.

This is a model/data compatibility check, not part of identification itself.
Given a directed acyclic graph and a finite observational joint distribution, it
checks the local Markov property:

    X ⟂ NonDescendants(X) \\ Pa(X) | Pa(X)

Only ordinary DAGs are supported. ADMGs with bidirected edges require an
m-separation style check and are intentionally rejected here.
"""

struct MarkovIndependenceFailure
    variable::Symbol
    independent_of::Vector{Symbol}
    given::Vector{Symbol}
    max_abs_diff::Float64
end

struct MarkovPropertyResult
    passed::Bool
    is_dag::Bool
    failures::Vector{MarkovIndependenceFailure}
    error::Union{Nothing,String}
end

function _model_directed_edges(model)
    hasproperty(model, :directed) ||
        error("model must have a directed edge list")
    return Pair{Symbol,Symbol}[Symbol(e.first) => Symbol(e.second) for e in getproperty(model, :directed)]
end

function _model_bidirected_edges(model)
    hasproperty(model, :bidirected) || return Pair{Symbol,Symbol}[]
    return Pair{Symbol,Symbol}[Symbol(e.first) => Symbol(e.second) for e in getproperty(model, :bidirected)]
end

function _dag_nodes(model, state::JointState)
    nodes = Set(variable_names(state.variables))
    for edge in _model_directed_edges(model)
        push!(nodes, edge.first)
        push!(nodes, edge.second)
    end
    return sort!(collect(nodes))
end

function _dag_parents(edges::Vector{Pair{Symbol,Symbol}}, node::Symbol)
    return sort!([edge.first for edge in edges if edge.second == node])
end

function _dag_children(edges::Vector{Pair{Symbol,Symbol}}, node::Symbol)
    return sort!([edge.second for edge in edges if edge.first == node])
end

function _dag_descendants(edges::Vector{Pair{Symbol,Symbol}}, node::Symbol)
    seen = Set{Symbol}()
    stack = collect(_dag_children(edges, node))
    while !isempty(stack)
        cur = pop!(stack)
        cur in seen && continue
        push!(seen, cur)
        append!(stack, _dag_children(edges, cur))
    end
    return seen
end

function _dag_ancestors(edges::Vector{Pair{Symbol,Symbol}}, starts::Vector{Symbol})
    reverse_edges = Pair{Symbol,Symbol}[edge.second => edge.first for edge in edges]
    seen = Set{Symbol}()
    stack = copy(starts)
    while !isempty(stack)
        cur = pop!(stack)
        cur in seen && continue
        push!(seen, cur)
        append!(stack, _dag_children(reverse_edges, cur))
    end
    return seen
end

function _is_directed_acyclic(edges::Vector{Pair{Symbol,Symbol}}, nodes::Vector{Symbol})
    temporary = Set{Symbol}()
    permanent = Set{Symbol}()

    function visit(node::Symbol)
        node in permanent && return true
        node in temporary && return false
        push!(temporary, node)
        for child in _dag_children(edges, node)
            visit(child) || return false
        end
        delete!(temporary, node)
        push!(permanent, node)
        return true
    end

    return all(visit(node) for node in nodes)
end

function _assert_state_contains(state::JointState, vars::Vector{Symbol})
    names = Set(variable_names(state.variables))
    missing = sort!(collect(setdiff(Set(vars), names)))
    isempty(missing) || error("joint state is missing graph variables: $(missing)")
end

function _prob_from_marginal(m::JointState, assignment::Tuple)
    isempty(m.variables) && return m.probabilities[]
    return m.probabilities[assignment...]
end

function _markov_box_role(box_val::Any)::Symbol
    val = string(box_val)
    startswith(val, "PU") && return :Exogenous
    startswith(val, "f_") && return :Mechanism
    return :Other
end

function _exogenous_wires_from_boxes(wd::WiringDiagram)::Set{Symbol}
    exogenous = Set{Symbol}()
    for b in box_ids(wd)
        b <= 0 && continue
        is_explicit_exogenous = _markov_box_role(box(wd, b).value) == :Exogenous
        is_source_box = isempty(input_ports(wd, b))
        (is_explicit_exogenous || is_source_box) || continue
        for v in _symbol_port_values(wd, b, OutputPort)
            push!(exogenous, v)
        end
    end
    return exogenous
end

function _shared_omitted_source_wires(
    wd::WiringDiagram,
    omitted_sources::Set{Symbol},
)::Vector{Symbol}
    target_boxes = Dict{Symbol,Set{Int}}(v => Set{Int}() for v in omitted_sources)
    for w in wires(wd)
        source_var = _port_symbol(wd, w.source)
        source_var in omitted_sources || continue
        w.target.box > 0 || continue
        push!(target_boxes[source_var], w.target.box)
    end
    return sort!([v for (v, targets) in target_boxes if length(targets) > 1])
end

function _full_variable_graph_from_diagram(
    wd::WiringDiagram,
    exogenous_vars::Set{Symbol},
)::Tuple{Vector{Symbol},Vector{Pair{Symbol,Symbol}}}
    nodes = sort!(collect(setdiff(diagram_variables(wd), exogenous_vars)))
    node_set = Set(nodes)
    edges = Pair{Symbol,Symbol}[]

    for b in box_ids(wd)
        b <= 0 && continue
        inputs = [v for v in _symbol_port_values(wd, b, InputPort) if v in node_set]
        outputs = [v for v in _symbol_port_values(wd, b, OutputPort) if v in node_set]
        for parent in inputs, child in outputs
            parent == child && continue
            push!(edges, parent => child)
        end
    end

    return nodes, sort!(unique(edges))
end

function _observed_descendants_through_latents(
    graph::Dict{Symbol,Set{Symbol}},
    start::Symbol,
    observed::Set{Symbol},
    latent::Set{Symbol},
)::Set{Symbol}
    out = Set{Symbol}()
    stack = collect(get(graph, start, Set{Symbol}()))
    seen = Set{Symbol}()
    while !isempty(stack)
        cur = pop!(stack)
        cur in seen && continue
        push!(seen, cur)
        if cur in observed
            push!(out, cur)
        elseif cur in latent
            append!(stack, collect(get(graph, cur, Set{Symbol}())))
        end
    end
    return out
end

function _latent_project_to_observed_admg(
    nodes::Vector{Symbol},
    edges::Vector{Pair{Symbol,Symbol}},
    observed::Set{Symbol},
)::Tuple{Vector{Pair{Symbol,Symbol}},Vector{Pair{Symbol,Symbol}}}
    latent = setdiff(Set(nodes), observed)
    graph = Dict{Symbol,Set{Symbol}}(n => Set{Symbol}() for n in nodes)
    for edge in edges
        push!(get!(graph, edge.first, Set{Symbol}()), edge.second)
        get!(graph, edge.second, Set{Symbol}())
    end

    directed = Pair{Symbol,Symbol}[]
    for source in observed
        stack = collect(get(graph, source, Set{Symbol}()))
        seen = Set{Symbol}()
        while !isempty(stack)
            cur = pop!(stack)
            cur in seen && continue
            push!(seen, cur)
            if cur in observed
                source == cur || push!(directed, source => cur)
            elseif cur in latent
                append!(stack, collect(get(graph, cur, Set{Symbol}())))
            end
        end
    end

    bidirected = Pair{Symbol,Symbol}[]
    for l in latent
        desc = sort!(collect(_observed_descendants_through_latents(graph, l, observed, latent)))
        for i in 1:length(desc), j in (i + 1):length(desc)
            push!(bidirected, desc[i] => desc[j])
        end
    end

    return sort!(unique(directed)), sort!(unique(bidirected))
end

function _subsets_symbols(xs::Vector{Symbol})
    n = length(xs)
    out = Vector{Vector{Symbol}}()
    for mask in 0:(2^n - 1)
        subset = Symbol[]
        for i in 1:n
            if (mask & (1 << (i - 1))) != 0
                push!(subset, xs[i])
            end
        end
        push!(out, subset)
    end
    return out
end

function _mixed_adjacency(
    directed::Vector{Pair{Symbol,Symbol}},
    bidirected::Vector{Pair{Symbol,Symbol}},
)
    adj = Dict{Symbol,Vector{Tuple{Symbol,Bool}}}()
    for edge in directed
        push!(get!(adj, edge.first, Tuple{Symbol,Bool}[]), (edge.second, false))
        push!(get!(adj, edge.second, Tuple{Symbol,Bool}[]), (edge.first, true))
    end
    for edge in bidirected
        push!(get!(adj, edge.first, Tuple{Symbol,Bool}[]), (edge.second, true))
        push!(get!(adj, edge.second, Tuple{Symbol,Bool}[]), (edge.first, true))
    end
    return adj
end

function _has_arrowhead_at(
    adj::Dict{Symbol,Vector{Tuple{Symbol,Bool}}},
    node::Symbol,
    neighbor::Symbol,
)::Bool
    matches = [head for (nbr, head) in get(adj, node, Tuple{Symbol,Bool}[]) if nbr == neighbor]
    isempty(matches) && error("no mixed edge between $(node) and $(neighbor)")
    return any(matches)
end

function _path_active_mixed(
    path::Vector{Symbol},
    adj::Dict{Symbol,Vector{Tuple{Symbol,Bool}}},
    conditioned::Set{Symbol},
    ancestors_of_conditioned::Set{Symbol},
)::Bool
    length(path) <= 2 && return true
    for i in 2:(length(path) - 1)
        prev, cur, nxt = path[i - 1], path[i], path[i + 1]
        head_from_prev = _has_arrowhead_at(adj, cur, prev)
        head_from_next = _has_arrowhead_at(adj, cur, nxt)
        collider = head_from_prev && head_from_next
        if collider
            cur in ancestors_of_conditioned || return false
        else
            cur in conditioned && return false
        end
    end
    return true
end

function _m_separated(
    nodes::Vector{Symbol},
    directed::Vector{Pair{Symbol,Symbol}},
    bidirected::Vector{Pair{Symbol,Symbol}},
    x::Symbol,
    y::Symbol,
    given::Vector{Symbol},
)::Bool
    adj = _mixed_adjacency(directed, bidirected)
    conditioned = Set(given)
    ancestors_of_conditioned = _dag_ancestors(directed, given)
    found_active = Ref(false)

    function dfs(cur::Symbol, target::Symbol, path::Vector{Symbol}, seen::Set{Symbol})
        found_active[] && return
        if cur == target
            if _path_active_mixed(path, adj, conditioned, ancestors_of_conditioned)
                found_active[] = true
            end
            return
        end
        for (nbr, _) in get(adj, cur, Tuple{Symbol,Bool}[])
            nbr in seen && continue
            push!(path, nbr)
            push!(seen, nbr)
            dfs(nbr, target, path, seen)
            pop!(path)
            delete!(seen, nbr)
        end
    end

    dfs(x, y, [x], Set([x]))
    return !found_active[]
end

function _validate_projected_admg_markov_property(
    nodes::Vector{Symbol},
    directed::Vector{Pair{Symbol,Symbol}},
    bidirected::Vector{Pair{Symbol,Symbol}},
    state::JointState;
    atol::Float64=1e-8,
    support_atol::Float64=1e-12,
)::MarkovPropertyResult
    is_dag = _is_directed_acyclic(directed, nodes)
    if !is_dag
        return MarkovPropertyResult(false, false, MarkovIndependenceFailure[], "projected directed graph contains a cycle")
    end

    failures = MarkovIndependenceFailure[]
    for i in 1:length(nodes), j in (i + 1):length(nodes)
        x, y = nodes[i], nodes[j]
        rest = [n for n in nodes if n != x && n != y]
        for given in _subsets_symbols(rest)
            _m_separated(nodes, directed, bidirected, x, y, given) || continue
            ok, max_abs_diff = conditional_independent(
                state,
                [x],
                [y],
                given;
                atol=atol,
                support_atol=support_atol,
            )
            ok || push!(failures, MarkovIndependenceFailure(x, [y], given, max_abs_diff))
        end
    end

    return MarkovPropertyResult(isempty(failures), true, failures, nothing)
end

"""
Check finite conditional independence X ⟂ Y | Z in a JointState.

Returns `(ok, max_abs_diff)`, where `max_abs_diff` is the largest violation of
`P(X,Y|Z) = P(X|Z)P(Y|Z)` over positive-probability assignments of `Z`.
"""
function conditional_independent(
    state::JointState,
    X::Vector{Symbol},
    Y::Vector{Symbol},
    Z::Vector{Symbol}=Symbol[];
    atol::Float64=1e-8,
    support_atol::Float64=1e-12,
)
    (isempty(X) || isempty(Y)) && return (true, 0.0)
    isempty(intersect(X, Y)) || error("X and Y must be disjoint")
    isempty(intersect(X, Z)) || error("X and Z must be disjoint")
    isempty(intersect(Y, Z)) || error("Y and Z must be disjoint")

    _assert_state_contains(state, vcat(X, Y, Z))

    xyz = marginal(state, vcat(X, Y, Z))
    xz = marginal(state, vcat(X, Z))
    yz = marginal(state, vcat(Y, Z))
    z_state = marginal(state, Z)

    x_vars = _variables_by_name(state.variables, X)
    y_vars = _variables_by_name(state.variables, Y)
    z_vars = _variables_by_name(state.variables, Z)

    x_indices = isempty(x_vars) ? [CartesianIndex()] : CartesianIndices(Tuple(length(v.values) for v in x_vars))
    y_indices = isempty(y_vars) ? [CartesianIndex()] : CartesianIndices(Tuple(length(v.values) for v in y_vars))
    z_indices = isempty(z_vars) ? [CartesianIndex()] : CartesianIndices(Tuple(length(v.values) for v in z_vars))

    max_abs_diff = 0.0
    for z_idx in z_indices
        z_tuple = Tuple(z_idx)
        p_z = _prob_from_marginal(z_state, z_tuple)
        p_z <= support_atol && continue
        for x_idx in x_indices
            x_tuple = Tuple(x_idx)
            p_xz = _prob_from_marginal(xz, (x_tuple..., z_tuple...))
            for y_idx in y_indices
                y_tuple = Tuple(y_idx)
                p_yz = _prob_from_marginal(yz, (y_tuple..., z_tuple...))
                p_xyz = _prob_from_marginal(xyz, (x_tuple..., y_tuple..., z_tuple...))
                lhs = p_xyz / p_z
                rhs = (p_xz / p_z) * (p_yz / p_z)
                max_abs_diff = max(max_abs_diff, abs(lhs - rhs))
            end
        end
    end

    return (max_abs_diff <= atol, max_abs_diff)
end

"""
Validate the local Markov property of a DAG against a finite JointState.

This function assumes the graph is intended to be a DAG. It rejects bidirected
edges because ADMG Markov properties require different separation semantics.
"""
function validate_markov_property(
    model,
    state::JointState;
    atol::Float64=1e-8,
    support_atol::Float64=1e-12,
)::MarkovPropertyResult
    try
        bidirected = _model_bidirected_edges(model)
        if !isempty(bidirected)
            return MarkovPropertyResult(
                false,
                false,
                MarkovIndependenceFailure[],
                "Markov validation currently supports DAGs only; bidirected edges were provided.",
            )
        end

        edges = _model_directed_edges(model)
        nodes = _dag_nodes(model, state)
        _assert_state_contains(state, nodes)

        return _validate_markov_property_edges(
            edges,
            nodes,
            state;
            atol=atol,
            support_atol=support_atol,
        )
    catch err
        return MarkovPropertyResult(false, false, MarkovIndependenceFailure[], sprint(showerror, err))
    end
end

function _validate_markov_property_edges(
    edges::Vector{Pair{Symbol,Symbol}},
    nodes::Vector{Symbol},
    state::JointState;
    atol::Float64=1e-8,
    support_atol::Float64=1e-12,
)::MarkovPropertyResult
    is_dag = _is_directed_acyclic(edges, nodes)
    if !is_dag
        return MarkovPropertyResult(false, false, MarkovIndependenceFailure[], "directed graph contains a cycle")
    end

    failures = MarkovIndependenceFailure[]
    all_nodes = Set(nodes)
    for node in nodes
        parents = _dag_parents(edges, node)
        descendants = _dag_descendants(edges, node)
        excluded = union(Set(parents), descendants, Set([node]))
        nondesc_nonparents = sort!(collect(setdiff(all_nodes, excluded)))
        isempty(nondesc_nonparents) && continue

        ok, max_abs_diff = conditional_independent(
            state,
            [node],
            nondesc_nonparents,
            parents;
            atol=atol,
            support_atol=support_atol,
        )
        ok || push!(failures, MarkovIndependenceFailure(node, nondesc_nonparents, parents, max_abs_diff))
    end

    return MarkovPropertyResult(isempty(failures), true, failures, nothing)
end

"""
Validate the Markov constraints induced by a Catlab wiring diagram on the
variables present in `state`.

The implementation constructs a variable-level DAG from the diagram, treats
variables absent from the supplied joint state as latent, projects the graph to
an observed ADMG, and checks the conditional independences implied by
m-separation.
"""
function validate_markov_property(
    wd::WiringDiagram,
    state::JointState;
    atol::Float64=1e-8,
    support_atol::Float64=1e-12,
)::MarkovPropertyResult
    try
        observed = Set(variable_names(state.variables))
        # Source/noise variables are kept as latent nodes for projection. If a
        # source feeds multiple observed mechanisms, the latent projection will
        # induce the corresponding bidirected edge rather than incorrectly
        # enforcing an ordinary DAG Markov constraint on the observed marginal.
        all_nodes, all_edges = _full_variable_graph_from_diagram(wd, Set{Symbol}())
        nodes = sort!(collect(observed))
        _assert_state_contains(state, nodes)
        projected_directed, projected_bidirected =
            _latent_project_to_observed_admg(all_nodes, all_edges, observed)

        return _validate_projected_admg_markov_property(
            nodes,
            projected_directed,
            projected_bidirected,
            state;
            atol=atol,
            support_atol=support_atol,
        )
    catch err
        return MarkovPropertyResult(false, false, MarkovIndependenceFailure[], sprint(showerror, err))
    end
end
