"""
Catlab-facing wrapper for the comb-only causal-inference extension.

This layer does not try to discover a general comb decomposition
automatically. Instead, the user supplies a `CombWitness`, and the tool checks
that this witness is at least consistent with the Catlab wiring diagram and the
finite observational joint distribution.
"""

using Catlab
using Catlab.WiringDiagrams

struct CombWitness
    A::Vector{Symbol}
    B::Vector{Symbol}
    C::Vector{Symbol}
    intervention::Vector{Symbol}

    function CombWitness(
        A::Vector{Symbol},
        B::Vector{Symbol},
        C::Vector{Symbol},
        intervention::Vector{Symbol},
    )
        _check_disjoint_groups(A, B, C)
        isempty(intervention) && error("CombWitness intervention must be non-empty")
        all(x -> x in A, intervention) ||
            error("CombWitness intervention variables must be contained in A")
        new(A, B, C, intervention)
    end
end

CombWitness(; A, B, C, intervention) =
    CombWitness(Vector{Symbol}(A), Vector{Symbol}(B), Vector{Symbol}(C), Vector{Symbol}(intervention))

struct SubdiagramBoundary
    boxes::Set{Int}
    input_wires::Vector{Wire}
    output_wires::Vector{Wire}
    internal_wires::Vector{Wire}
    input_vars::Vector{Symbol}
    output_vars::Vector{Symbol}
end

struct CombSubdiagramProof
    witness::CombWitness
    g_boxes::Vector{Int}
    g_boundary::SubdiagramBoundary
end

struct FcutSubdiagramProof
    witness::CombWitness
    fcut_boxes::Vector{Int}
    fcut_boundary::SubdiagramBoundary
end

struct FSubdiagramProof
    witness::CombWitness
    f_boxes::Vector{Int}
    f_boundary::SubdiagramBoundary
end

struct CutCombSubdiagramProof
    witness::CombWitness
    g_proof::CombSubdiagramProof
    f_proof::FSubdiagramProof
end

struct CombOnlyCausalEffectResult
    computable::Bool
    effect::Union{Nothing,StochChannel}
    comb::Union{Nothing,TwoComb}
    reconstructed::Union{Nothing,JointState}
    reconstruction_ok::Bool
    failure_reason::Union{Nothing,String}
    witness::CombWitness
    surgery_diagram::Union{Nothing,WiringDiagram}
    subdiagram_proof::Union{Nothing,CutCombSubdiagramProof}
end

function _symbol_port_values(wd::WiringDiagram, b::Int, port_kind)
    ports = port_kind == InputPort ? input_ports(wd, b) : output_ports(wd, b)
    values = Symbol[]
    for i in 1:length(ports)
        v = Catlab.WiringDiagrams.port_value(wd, Port(b, port_kind, i))
        v isa Symbol && push!(values, v)
    end
    return values
end

function _wire_source_inside(wire::Wire, boxes::Set{Int})::Bool
    return wire.source.box in boxes
end

function _wire_target_inside(wire::Wire, boxes::Set{Int})::Bool
    return wire.target.box in boxes
end

function _port_symbol(wd::WiringDiagram, port::Port)
    v = Catlab.WiringDiagrams.port_value(wd, port)
    return v isa Symbol ? v : nothing
end

function _unique_symbols_in_order(vals)
    seen = Set{Symbol}()
    out = Symbol[]
    for v in vals
        v === nothing && continue
        v in seen && continue
        push!(seen, v)
        push!(out, v)
    end
    return out
end

"""
Compute the boundary of a candidate subdiagram.

Given a set of internal boxes, wires are classified as:

- internal: source and target are both inside the box set
- input:    source is outside, target is inside
- output:   source is inside, target is outside

The resulting `input_vars` and `output_vars` preserve first-seen order while
removing duplicates.
"""
function subdiagram_boundary(wd::WiringDiagram, boxes::AbstractVector{Int})::SubdiagramBoundary
    box_set = Set(boxes)
    all(b -> b > 0, box_set) || error("subdiagram boxes must be internal positive box ids")
    all(b -> b in box_ids(wd), box_set) || error("subdiagram contains box ids not present in diagram")

    input_wires = Wire[]
    output_wires = Wire[]
    internal_wires = Wire[]

    for w in wires(wd)
        source_inside = _wire_source_inside(w, box_set)
        target_inside = _wire_target_inside(w, box_set)

        if source_inside && target_inside
            push!(internal_wires, w)
        elseif !source_inside && target_inside
            push!(input_wires, w)
        elseif source_inside && !target_inside
            push!(output_wires, w)
        end
    end

    input_vars = _unique_symbols_in_order([_port_symbol(wd, w.target) for w in input_wires])
    output_vars = _unique_symbols_in_order([_port_symbol(wd, w.source) for w in output_wires])

    return SubdiagramBoundary(
        box_set,
        input_wires,
        output_wires,
        internal_wires,
        input_vars,
        output_vars,
    )
end

function boundary_matches(
    boundary::SubdiagramBoundary;
    inputs::Vector{Symbol},
    outputs::Vector{Symbol},
    ordered::Bool=false,
)::Bool
    if ordered
        return boundary.input_vars == inputs && boundary.output_vars == outputs
    end
    return Set(boundary.input_vars) == Set(inputs) && Set(boundary.output_vars) == Set(outputs)
end

"""
Extract a conservative variable-level directed graph from a wiring diagram.

For each internal box, every observed input variable is treated as a parent of
every observed output variable. Variables not present in `observed` are ignored;
this filters out exogenous noise wires such as `U_X`.
"""
function extract_variable_graph(
    wd::WiringDiagram;
    observed::Union{Nothing,Set{Symbol}}=nothing,
)::Dict{Symbol,Set{Symbol}}
    vars = observed === nothing ? diagram_variables(wd) : observed
    graph = Dict{Symbol,Set{Symbol}}(v => Set{Symbol}() for v in vars)

    for b in box_ids(wd)
        b <= 0 && continue
        parents = [v for v in _symbol_port_values(wd, b, InputPort) if v in vars]
        children = [v for v in _symbol_port_values(wd, b, OutputPort) if v in vars]

        for parent in parents
            for child in children
                parent == child && continue
                push!(get!(graph, parent, Set{Symbol}()), child)
                get!(graph, child, Set{Symbol}())
            end
        end
    end

    return graph
end

function _box_inputs_outputs(
    wd::WiringDiagram,
    b::Int;
    observed::Set{Symbol},
)::Tuple{Vector{Symbol},Vector{Symbol}}
    inputs = [v for v in _symbol_port_values(wd, b, InputPort) if v in observed]
    outputs = [v for v in _symbol_port_values(wd, b, OutputPort) if v in observed]
    return inputs, outputs
end

function candidate_g_boxes(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::Vector{Int}
    observed = Set(variable_names(state.variables))
    reachable_from_A = _nodes_reachable_from(
        extract_variable_graph(wd; observed=observed),
        witness.A,
    )
    reaches_B = _nodes_that_reach(
        extract_variable_graph(wd; observed=observed),
        witness.B,
    )
    g_region_vars = intersect(reachable_from_A, reaches_B)
    setdiff!(g_region_vars, Set(witness.B))

    boxes = Int[]
    allowed_g_inputs = union(g_region_vars, Set(witness.A), Set(witness.B))
    for b in box_ids(wd)
        b <= 0 && continue
        inputs, outputs = _box_inputs_outputs(wd, b; observed=observed)
        isempty(outputs) && continue
        all(v -> v in g_region_vars || v in witness.B, outputs) || continue
        (
            any(v -> v in g_region_vars || v in witness.A, inputs) ||
            (any(v -> v in witness.B, outputs) && all(v -> v in allowed_g_inputs, inputs))
        ) || continue
        push!(boxes, b)
    end

    return sort(boxes)
end

function candidate_fcut_boxes(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::Vector{Int}
    observed = Set(variable_names(state.variables))
    graph = extract_variable_graph(wd; observed=observed)
    reachable_from_B = _nodes_reachable_from(graph, witness.B)
    reaches_C = _nodes_that_reach(graph, witness.C)
    f_region_vars = intersect(reachable_from_B, reaches_C)
    setdiff!(f_region_vars, Set(witness.C))

    boxes = Int[]
    for b in box_ids(wd)
        b <= 0 && continue
        inputs, outputs = _box_inputs_outputs(wd, b; observed=observed)
        isempty(outputs) && continue
        all(v -> v in f_region_vars || v in witness.C, outputs) || continue
        any(v -> v in f_region_vars || v in witness.B, inputs) || continue
        push!(boxes, b)
    end

    return sort(boxes)
end

function candidate_f_boxes(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    g_boxes::Vector{Int},
)::Vector{Int}
    observed = Set(variable_names(state.variables))
    f_output_vars = Set(vcat(witness.A, witness.C))
    f_input_vars = Set(witness.B)

    boxes = Set{Int}()
    for b in box_ids(wd)
        b <= 0 && continue
        b in g_boxes && continue
        inputs, outputs = _box_inputs_outputs(wd, b; observed=observed)

        # Keep boxes that contribute observed A/C outputs, and boxes whose
        # observed outputs feed those boxes through latent/internal structure.
        if any(v -> v in f_output_vars, outputs) ||
           any(v -> v in f_input_vars, inputs)
            push!(boxes, b)
        end
    end

    # Close the f-region backwards over latent/internal wires. This includes
    # hidden-state generators such as h in the smoking example when they feed a
    # selected f-box, while still excluding the already-proved g-region.
    changed = true
    g_set = Set(g_boxes)
    while changed
        changed = false
        for w in wires(wd)
            target_box = w.target.box
            source_box = w.source.box
            target_box in boxes || continue
            source_box <= 0 && continue
            source_box in g_set && continue
            source_box in boxes && continue
            push!(boxes, source_box)
            changed = true
        end
    end

    return sort(collect(boxes))
end

function prove_g_subdiagram(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::CombSubdiagramProof
    validate_comb_witness(wd, state, witness)

    g_boxes = candidate_g_boxes(wd, state, witness)
    isempty(g_boxes) && error("could not prove g subdiagram: no candidate boxes found")

    g_boundary = subdiagram_boundary(wd, g_boxes)
    boundary_matches(g_boundary; inputs=witness.A, outputs=witness.B) ||
        error("could not prove g subdiagram: expected boundary $(witness.A) -> $(witness.B), got $(g_boundary.input_vars) -> $(g_boundary.output_vars)")

    return CombSubdiagramProof(witness, g_boxes, g_boundary)
end

function prove_fcut_subdiagram(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::FcutSubdiagramProof
    validate_comb_witness(wd, state, witness)

    fcut_boxes = candidate_fcut_boxes(wd, state, witness)
    isempty(fcut_boxes) && error("could not prove f_cut subdiagram: no candidate boxes found")

    fcut_boundary = subdiagram_boundary(wd, fcut_boxes)
    boundary_matches(fcut_boundary; inputs=witness.B, outputs=witness.C) ||
        error("could not prove f_cut subdiagram: expected boundary $(witness.B) -> $(witness.C), got $(fcut_boundary.input_vars) -> $(fcut_boundary.output_vars)")

    return FcutSubdiagramProof(witness, fcut_boxes, fcut_boundary)
end

function prove_f_subdiagram(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    g_proof::CombSubdiagramProof,
)::FSubdiagramProof
    validate_comb_witness(wd, state, witness)

    f_boxes = candidate_f_boxes(wd, state, witness, g_proof.g_boxes)
    isempty(f_boxes) && error("could not prove f subdiagram: no candidate boxes found")

    f_boundary = subdiagram_boundary(wd, f_boxes)
    expected_outputs = vcat(witness.A, witness.C)
    boundary_matches(f_boundary; inputs=witness.B, outputs=expected_outputs) ||
        error("could not prove f subdiagram: expected boundary $(witness.B) -> $(expected_outputs), got $(f_boundary.input_vars) -> $(f_boundary.output_vars)")

    return FSubdiagramProof(witness, f_boxes, f_boundary)
end

function prove_cut_comb_subdiagrams(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::CutCombSubdiagramProof
    g_proof = prove_g_subdiagram(wd, state, witness)
    f_proof = prove_f_subdiagram(wd, state, witness, g_proof)

    overlap = intersect(Set(g_proof.g_boxes), Set(f_proof.f_boxes))
    isempty(overlap) ||
        error("could not prove cut-comb subdiagrams: g and f boxes overlap: $(sort(collect(overlap)))")

    return CutCombSubdiagramProof(witness, g_proof, f_proof)
end

function _nodes_reachable_from(graph::Dict{Symbol,Set{Symbol}}, starts::Vector{Symbol})::Set{Symbol}
    visited = Set{Symbol}()
    stack = copy(starts)
    while !isempty(stack)
        node = pop!(stack)
        node in visited && continue
        push!(visited, node)
        for child in get(graph, node, Set{Symbol}())
            child in visited || push!(stack, child)
        end
    end
    return visited
end

function _nodes_that_reach(graph::Dict{Symbol,Set{Symbol}}, targets::Vector{Symbol})::Set{Symbol}
    reverse_graph = Dict{Symbol,Set{Symbol}}()
    for node in keys(graph)
        get!(reverse_graph, node, Set{Symbol}())
    end
    for (parent, children) in graph
        for child in children
            push!(get!(reverse_graph, child, Set{Symbol}()), parent)
        end
    end
    return _nodes_reachable_from(reverse_graph, targets)
end

function _all_directed_paths(
    graph::Dict{Symbol,Set{Symbol}},
    starts::Vector{Symbol},
    targets::Vector{Symbol},
)::Vector{Vector{Symbol}}
    target_set = Set(targets)
    paths = Vector{Vector{Symbol}}()

    function dfs(node::Symbol, path::Vector{Symbol}, seen::Set{Symbol})
        if node in target_set
            push!(paths, copy(path))
            return
        end

        for child in sort(collect(get(graph, node, Set{Symbol}())))
            child in seen && continue
            push!(path, child)
            push!(seen, child)
            dfs(child, path, seen)
            pop!(path)
            delete!(seen, child)
        end
    end

    for start in starts
        haskey(graph, start) || continue
        dfs(start, Symbol[start], Set(Symbol[start]))
    end

    return paths
end

function validate_comb_paths(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)
    observed = Set(variable_names(state.variables))
    graph = extract_variable_graph(wd; observed=observed)
    paths = _all_directed_paths(graph, witness.intervention, witness.C)

    isempty(paths) &&
        error("could not validate comb witness: no directed path from intervention to outcome")

    bridge_set = Set(witness.B)
    path_intermediates = Set{Symbol}()

    for path in paths
        middle = path[2:(end - 1)]
        if isempty(middle)
            error("could not validate comb witness: direct intervention-to-outcome path bypasses bridge: $(path)")
        end

        middle_set = Set(middle)
        union!(path_intermediates, middle_set)

        unaccounted = setdiff(middle_set, bridge_set)
        isempty(unaccounted) ||
            error("could not validate comb witness: path $(path) contains intermediate variables not in bridge: $(sort(collect(unaccounted)))")
    end

    unused_bridge = setdiff(bridge_set, path_intermediates)
    isempty(unused_bridge) ||
        error("could not validate comb witness: bridge variables are not on any intervention-to-outcome path: $(sort(collect(unused_bridge)))")

    return true
end

"""
Conservatively discover a comb witness from a DAG-like wiring diagram.

The bridge set is the set of observed variables lying on directed paths from
the intervention variables to the outcome variables, excluding the endpoints.
If any outcome is unreachable, discovery fails.
"""
function discover_comb_witness(
    wd::WiringDiagram,
    state::JointState;
    intervention::Vector{Symbol},
    outcome::Vector{Symbol},
)::CombWitness
    isempty(intervention) && error("intervention must be non-empty")
    isempty(outcome) && error("outcome must be non-empty")
    isempty(intersect(intervention, outcome)) ||
        error("intervention and outcome variables must be disjoint")

    observed = Set(variable_names(state.variables))
    diagram_vars = diagram_variables(wd)

    missing_in_diagram = setdiff(Set(vcat(intervention, outcome)), diagram_vars)
    isempty(missing_in_diagram) ||
        error("intervention/outcome variables not found in diagram: $(sort(collect(missing_in_diagram)))")

    missing_in_state = setdiff(Set(vcat(intervention, outcome)), observed)
    isempty(missing_in_state) ||
        error("intervention/outcome variables not found in joint distribution: $(sort(collect(missing_in_state)))")

    graph = extract_variable_graph(wd; observed=observed)
    paths = _all_directed_paths(graph, intervention, outcome)
    isempty(paths) ||
        all(path -> length(path) >= 3, paths) ||
        error("could not discover comb witness: direct intervention-to-outcome path bypasses bridge")

    isempty(paths) &&
        error("could not discover comb witness: outcomes not reachable from intervention in diagram: $(outcome)")

    bridge_set = Set{Symbol}()
    for path in paths
        union!(bridge_set, Set(path[2:(end - 1)]))
    end
    bridge = sort(collect(bridge_set))

    isempty(bridge) &&
        error("could not discover comb witness: no bridge variables found on intervention-to-outcome paths")

    witness = CombWitness(
        A=intervention,
        B=bridge,
        C=outcome,
        intervention=intervention,
    )
    validate_comb_paths(wd, state, witness)
    return witness
end

function diagram_variables(wd::WiringDiagram)::Set{Symbol}
    vars = Set{Symbol}()

    for v in input_ports(wd)
        v isa Symbol && push!(vars, v)
    end
    for v in output_ports(wd)
        v isa Symbol && push!(vars, v)
    end

    for b in box_ids(wd)
        b <= 0 && continue
        for i in 1:length(input_ports(wd, b))
            v = Catlab.WiringDiagrams.port_value(wd, Port(b, InputPort, i))
            v isa Symbol && push!(vars, v)
        end
        for i in 1:length(output_ports(wd, b))
            v = Catlab.WiringDiagrams.port_value(wd, Port(b, OutputPort, i))
            v isa Symbol && push!(vars, v)
        end
    end

    return vars
end

function validate_comb_witness(wd::WiringDiagram, state::JointState, witness::CombWitness)
    diagram_vars = diagram_variables(wd)
    state_vars = Set(variable_names(state.variables))
    witness_vars = Set(vcat(witness.A, witness.B, witness.C))

    missing_in_diagram = setdiff(witness_vars, diagram_vars)
    isempty(missing_in_diagram) ||
        error("comb witness variables not found in diagram: $(sort(collect(missing_in_diagram)))")

    missing_in_state = setdiff(witness_vars, state_vars)
    isempty(missing_in_state) ||
        error("comb witness variables not found in joint distribution: $(sort(collect(missing_in_state)))")

    all(x -> x in witness.A, witness.intervention) ||
        error("intervention variables must be contained in witness A")

    return true
end

"""
Build the abstract surgery diagram A -> g -> B -> f_cut -> C.

This is the cut comb diagram used for evaluation, not an automatic rewrite of
the original diagram.
"""
function build_cut_comb_diagram(witness::CombWitness)::WiringDiagram
    wd = WiringDiagram(Any[witness.intervention...], Any[witness.C...])

    g_box = add_box!(wd, Box(:g_comb, Any[witness.intervention...], Any[witness.B...]))
    f_box = add_box!(wd, Box(:f_cut, Any[witness.B...], Any[witness.C...]))

    for (i, _) in enumerate(witness.intervention)
        add_wire!(wd, Port(input_id(wd), OutputPort, i) => Port(g_box, InputPort, i))
    end

    for (i, _) in enumerate(witness.B)
        add_wire!(wd, Port(g_box, OutputPort, i) => Port(f_box, InputPort, i))
    end

    for (i, _) in enumerate(witness.C)
        add_wire!(wd, Port(f_box, OutputPort, i) => Port(output_id(wd), InputPort, i))
    end

    return wd
end

"""
Diagram-aware comb-only causal inference.

The Catlab diagram is used to validate that the user-supplied comb witness is
consistent with the diagram vocabulary and to build the abstract surgery
diagram. The numerical computation is delegated to `infer_causal_effect`.
"""
function infer_causal_effect(
    wd::WiringDiagram,
    state::JointState;
    witness::Union{Nothing,CombWitness}=nothing,
    intervention::Union{Nothing,Vector{Symbol}}=nothing,
    bridge::Union{Nothing,Vector{Symbol}}=nothing,
    outcome::Union{Nothing,Vector{Symbol}}=nothing,
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
)::CombOnlyCausalEffectResult
    local resolved_witness::CombWitness
    try
        if witness === nothing
            intervention === nothing && error("either witness or intervention/bridge/outcome must be provided")
            outcome === nothing && error("either witness or intervention/bridge/outcome must be provided")
            if bridge === nothing
                resolved_witness = discover_comb_witness(
                    wd,
                    state;
                    intervention=intervention,
                    outcome=outcome,
                )
            else
                resolved_witness = CombWitness(
                    A=intervention,
                    B=bridge,
                    C=outcome,
                    intervention=intervention,
                )
            end
        else
            resolved_witness = witness
        end

        validate_comb_witness(wd, state, resolved_witness)
        subdiagram_proof = prove_cut_comb_subdiagrams(wd, state, resolved_witness)

        base = infer_causal_effect(
            state;
            A=resolved_witness.A,
            B=resolved_witness.B,
            C=resolved_witness.C,
            require_full_support=require_full_support,
            reconstruction_atol=reconstruction_atol,
        )

        surgery_diagram = base.computable ? build_cut_comb_diagram(resolved_witness) : nothing

        return CombOnlyCausalEffectResult(
            base.computable,
            base.effect,
            base.comb,
            base.reconstructed,
            base.reconstruction_ok,
            base.failure_reason,
            resolved_witness,
            surgery_diagram,
            subdiagram_proof,
        )
    catch err
        fallback_witness = witness === nothing ?
            CombWitness(Symbol[:__invalid__], Symbol[], Symbol[], Symbol[:__invalid__]) :
            witness
        return CombOnlyCausalEffectResult(
            false,
            nothing,
            nothing,
            nothing,
            false,
            sprint(showerror, err),
            fallback_witness,
            nothing,
            nothing,
        )
    end
end
