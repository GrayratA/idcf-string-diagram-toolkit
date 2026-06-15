"""
Catlab-facing wrapper for the comb-only causal-inference extension.

This layer implements the scoped comb-disintegration interface used by the
causal-inference extension. The normal user input names the context,
intervention, bridge, and outcome variables. Internally, these are converted to
the comb boundary `(A,B,C)`, where `A = context ∪ intervention`. The tool proves a
diagrammatic comb decomposition by finding a partition of all internal boxes
into `g` and `f` regions, then checking their boundaries.
"""

using Catlab
using Catlab.WiringDiagrams

struct CombWitness
    A::Vector{Symbol}
    B::Vector{Symbol}
    C::Vector{Symbol}
    intervention::Vector{Symbol}
    context::Vector{Symbol}

    function CombWitness(
        A::Vector{Symbol},
        B::Vector{Symbol},
        C::Vector{Symbol},
        intervention::Vector{Symbol},
        context::Vector{Symbol}=Symbol[],
    )
        _check_disjoint_groups(A, B, C)
        isempty(intervention) && error("CombWitness intervention must be non-empty")
        all(x -> x in A, intervention) ||
            error("CombWitness intervention variables must be contained in A")
        all(x -> x in A, context) ||
            error("CombWitness context variables must be contained in A")
        isempty(intersect(intervention, context)) ||
            error("CombWitness intervention and context variables must be disjoint")
        new(A, B, C, intervention, context)
    end
end

CombWitness(; A, B, C, intervention, context=Symbol[]) =
    CombWitness(
        Vector{Symbol}(A),
        Vector{Symbol}(B),
        Vector{Symbol}(C),
        Vector{Symbol}(intervention),
        Vector{Symbol}(context),
    )

"""
User-supplied comb structure.

The preferred user-facing constructor is:

    CombStructure(
        context=[...],
        intervention=[...],
        bridge=[...],
        outcome=[...],
    )

Internally this creates the comb boundary `A = context ∪ intervention`,
`B = bridge`, and `C = outcome`.

The older `(A,B,C,intervention,context)` constructor is kept for compatibility.
By default, the implementation
identifies the `g` subdiagram automatically and treats all remaining internal
boxes as `f`, then verifies the boundaries `g : A -> B` and
`f : B -> A x C`. The recognizer first tries a fast graph-based candidate and
then falls back to exhaustive finite search, so it is complete for this
syntactic comb-shape check on finite Catlab wiring diagrams.

Optional `g_boxes` and `f_boxes` are an explicit override for debugging or for
examples where the user wants to name the regions directly. Box references may
be internal Catlab box ids or box labels such as `:t`.
"""
struct CombStructure
    witness::CombWitness
    g_boxes::Union{Nothing,Vector{Any}}
    f_boxes::Union{Nothing,Vector{Any}}
    cover_all_boxes::Bool
end

function CombStructure(
    witness::CombWitness;
    g_boxes::Union{Nothing,AbstractVector}=nothing,
    f_boxes::Union{Nothing,AbstractVector}=nothing,
    cover_all_boxes::Bool=false,
)
    return CombStructure(
        witness,
        g_boxes === nothing ? nothing : collect(Any, g_boxes),
        f_boxes === nothing ? nothing : collect(Any, f_boxes),
        cover_all_boxes,
    )
end

function CombStructure(;
    A=nothing,
    B=nothing,
    C=nothing,
    context=Symbol[],
    intervention,
    bridge=nothing,
    outcome=nothing,
    g_boxes=nothing,
    f_boxes=nothing,
    cover_all_boxes::Bool=false,
)
    context_vars = Vector{Symbol}(context)
    intervention_vars = Vector{Symbol}(intervention)

    if bridge !== nothing || outcome !== nothing
        (A === nothing && B === nothing && C === nothing) ||
            error("provide either context/intervention/bridge/outcome or legacy A/B/C/intervention, not both")
        bridge === nothing && error("bridge must be provided with the new CombStructure interface")
        outcome === nothing && error("outcome must be provided with the new CombStructure interface")
        return CombStructure(
            CombWitness(
                A=vcat(context_vars, intervention_vars),
                B=Vector{Symbol}(bridge),
                C=Vector{Symbol}(outcome),
                intervention=intervention_vars,
                context=context_vars,
            );
            g_boxes=g_boxes,
            f_boxes=f_boxes,
            cover_all_boxes=cover_all_boxes,
        )
    end

    (A !== nothing && B !== nothing && C !== nothing) ||
        error("provide context/intervention/bridge/outcome, or legacy A/B/C/intervention")
    return CombStructure(
        CombWitness(; A=A, B=B, C=C, intervention=intervention, context=context);
        g_boxes=g_boxes,
        f_boxes=f_boxes,
        cover_all_boxes=cover_all_boxes,
    )
end

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

struct CombDiagramIndex
    internal_boxes::Vector{Int}
    internal_set::Set{Int}
    diagram_vars::Set{Symbol}
    wires::Vector{Wire}
    wire_source_symbols::Vector{Union{Nothing,Symbol}}
    wire_target_symbols::Vector{Union{Nothing,Symbol}}
    incoming_internal::Dict{Int,Vector{Int}}
    output_ports_by_var::Dict{Symbol,Vector{Int}}
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
    if port.box == input_id(wd) && port.kind == OutputPort
        v = input_ports(wd)[port.port]
        return v isa Symbol ? v : nothing
    end
    if port.box == output_id(wd) && port.kind == InputPort
        v = output_ports(wd)[port.port]
        return v isa Symbol ? v : nothing
    end
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

    return _subdiagram_boundary_unchecked(wd, box_set)
end

function _subdiagram_boundary_unchecked(wd::WiringDiagram, box_set::Set{Int})::SubdiagramBoundary
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

function _partition_boundaries_unchecked(
    wd::WiringDiagram,
    g_set::Set{Int},
    f_set::Set{Int},
)::Tuple{SubdiagramBoundary,SubdiagramBoundary}
    g_input_wires = Wire[]
    g_output_wires = Wire[]
    g_internal_wires = Wire[]
    g_input_symbols = Union{Nothing,Symbol}[]
    g_output_symbols = Union{Nothing,Symbol}[]

    f_input_wires = Wire[]
    f_output_wires = Wire[]
    f_internal_wires = Wire[]
    f_input_symbols = Union{Nothing,Symbol}[]
    f_output_symbols = Union{Nothing,Symbol}[]

    for w in wires(wd)
        source_g = w.source.box in g_set
        target_g = w.target.box in g_set
        source_f = w.source.box in f_set
        target_f = w.target.box in f_set

        if source_g && target_g
            push!(g_internal_wires, w)
        elseif !source_g && target_g
            push!(g_input_wires, w)
            push!(g_input_symbols, _port_symbol(wd, w.target))
        elseif source_g && !target_g
            push!(g_output_wires, w)
            push!(g_output_symbols, _port_symbol(wd, w.source))
        end

        if source_f && target_f
            push!(f_internal_wires, w)
        elseif !source_f && target_f
            push!(f_input_wires, w)
            push!(f_input_symbols, _port_symbol(wd, w.target))
        elseif source_f && !target_f
            push!(f_output_wires, w)
            push!(f_output_symbols, _port_symbol(wd, w.source))
        end
    end

    g_boundary = SubdiagramBoundary(
        g_set,
        g_input_wires,
        g_output_wires,
        g_internal_wires,
        _unique_symbols_in_order(g_input_symbols),
        _unique_symbols_in_order(g_output_symbols),
    )
    f_boundary = SubdiagramBoundary(
        f_set,
        f_input_wires,
        f_output_wires,
        f_internal_wires,
        _unique_symbols_in_order(f_input_symbols),
        _unique_symbols_in_order(f_output_symbols),
    )

    return g_boundary, f_boundary
end

function _partition_boundaries_unchecked(
    index::CombDiagramIndex,
    g_set::Set{Int},
    f_set::Set{Int},
)::Tuple{SubdiagramBoundary,SubdiagramBoundary}
    g_input_wires = Wire[]
    g_output_wires = Wire[]
    g_internal_wires = Wire[]
    g_input_symbols = Union{Nothing,Symbol}[]
    g_output_symbols = Union{Nothing,Symbol}[]

    f_input_wires = Wire[]
    f_output_wires = Wire[]
    f_internal_wires = Wire[]
    f_input_symbols = Union{Nothing,Symbol}[]
    f_output_symbols = Union{Nothing,Symbol}[]

    for (i, w) in enumerate(index.wires)
        source_g = w.source.box in g_set
        target_g = w.target.box in g_set
        source_f = w.source.box in f_set
        target_f = w.target.box in f_set

        if source_g && target_g
            push!(g_internal_wires, w)
        elseif !source_g && target_g
            push!(g_input_wires, w)
            push!(g_input_symbols, index.wire_target_symbols[i])
        elseif source_g && !target_g
            push!(g_output_wires, w)
            push!(g_output_symbols, index.wire_source_symbols[i])
        end

        if source_f && target_f
            push!(f_internal_wires, w)
        elseif !source_f && target_f
            push!(f_input_wires, w)
            push!(f_input_symbols, index.wire_target_symbols[i])
        elseif source_f && !target_f
            push!(f_output_wires, w)
            push!(f_output_symbols, index.wire_source_symbols[i])
        end
    end

    g_boundary = SubdiagramBoundary(
        g_set,
        g_input_wires,
        g_output_wires,
        g_internal_wires,
        _unique_symbols_in_order(g_input_symbols),
        _unique_symbols_in_order(g_output_symbols),
    )
    f_boundary = SubdiagramBoundary(
        f_set,
        f_input_wires,
        f_output_wires,
        f_internal_wires,
        _unique_symbols_in_order(f_input_symbols),
        _unique_symbols_in_order(f_output_symbols),
    )

    return g_boundary, f_boundary
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

function _resolve_box_id(wd::WiringDiagram, ref)::Int
    if ref isa Integer
        id = Int(ref)
        id in box_ids(wd) && id > 0 ||
            error("box id $(id) is not an internal box in the diagram")
        return id
    end

    matches = Int[]
    for b in box_ids(wd)
        b <= 0 && continue
        value = box(wd, b).value
        if value == ref || string(value) == string(ref)
            push!(matches, b)
        end
    end

    isempty(matches) && error("box reference $(ref) was not found in the diagram")
    length(matches) == 1 ||
        error("box reference $(ref) is ambiguous; matching ids are $(matches)")
    return only(matches)
end

function resolve_box_ids(wd::WiringDiagram, refs::AbstractVector)::Vector{Int}
    ids = [_resolve_box_id(wd, ref) for ref in refs]
    length(unique(ids)) == length(ids) ||
        error("box references contain duplicates after resolution: $(ids)")
    return ids
end

_internal_box_ids(wd::WiringDiagram)::Vector{Int} =
    sort([b for b in box_ids(wd) if b > 0])

function _comb_diagram_index(wd::WiringDiagram)::CombDiagramIndex
    internal_boxes = _internal_box_ids(wd)
    internal_set = Set(internal_boxes)
    diagram_vars = Set{Symbol}()

    output_ports_by_var = Dict{Symbol,Vector{Int}}()
    for v in input_ports(wd)
        v isa Symbol && push!(diagram_vars, v)
    end
    for (i, v) in enumerate(output_ports(wd))
        if v isa Symbol
            push!(diagram_vars, v)
            push!(get!(output_ports_by_var, v, Int[]), i)
        end
    end

    for b in internal_boxes
        for i in 1:length(input_ports(wd, b))
            v = Catlab.WiringDiagrams.port_value(wd, Port(b, InputPort, i))
            v isa Symbol && push!(diagram_vars, v)
        end
        for i in 1:length(output_ports(wd, b))
            v = Catlab.WiringDiagrams.port_value(wd, Port(b, OutputPort, i))
            v isa Symbol && push!(diagram_vars, v)
        end
    end

    wire_vec = collect(wires(wd))
    source_symbols = Union{Nothing,Symbol}[]
    target_symbols = Union{Nothing,Symbol}[]
    incoming_internal = Dict{Int,Vector{Int}}()

    for (i, w) in enumerate(wire_vec)
        push!(source_symbols, _port_symbol(wd, w.source))
        push!(target_symbols, _port_symbol(wd, w.target))
        if w.target.box > 0 && w.source.box > 0
            push!(get!(incoming_internal, w.target.box, Int[]), i)
        end
    end

    return CombDiagramIndex(
        internal_boxes,
        internal_set,
        diagram_vars,
        wire_vec,
        source_symbols,
        target_symbols,
        incoming_internal,
        output_ports_by_var,
    )
end

function _incoming_internal_wires_by_target(wd::WiringDiagram)::Dict{Int,Vector{Wire}}
    incoming = Dict{Int,Vector{Wire}}()
    for w in wires(wd)
        w.target.box > 0 || continue
        w.source.box > 0 || continue
        push!(get!(incoming, w.target.box, Wire[]), w)
    end
    return incoming
end

function _close_backward_over_nonboundary_inputs!(
    wd::WiringDiagram,
    box_set::Set{Int},
    boundary_symbols::Set{Symbol};
    exclude_boxes::Set{Int}=Set{Int}(),
)
    incoming = _incoming_internal_wires_by_target(wd)
    queue = collect(box_set)
    visited = Set{Int}()

    while !isempty(queue)
        target_box = pop!(queue)
        target_box in visited && continue
        push!(visited, target_box)

        for w in get(incoming, target_box, Wire[])
            source_box = w.source.box
            source_box in box_set && continue
            source_box in exclude_boxes && continue
            source_symbol = _port_symbol(wd, w.source)
            source_symbol in boundary_symbols && continue

            push!(box_set, source_box)
            push!(queue, source_box)
        end
    end

    return box_set
end

function _close_backward_over_nonboundary_inputs!(
    index::CombDiagramIndex,
    box_set::Set{Int},
    boundary_symbols::Set{Symbol};
    exclude_boxes::Set{Int}=Set{Int}(),
)
    queue = collect(box_set)
    visited = Set{Int}()

    while !isempty(queue)
        target_box = pop!(queue)
        target_box in visited && continue
        push!(visited, target_box)

        for wire_idx in get(index.incoming_internal, target_box, Int[])
            w = index.wires[wire_idx]
            source_box = w.source.box
            source_box in box_set && continue
            source_box in exclude_boxes && continue
            source_symbol = index.wire_source_symbols[wire_idx]
            source_symbol in boundary_symbols && continue

            push!(box_set, source_box)
            push!(queue, source_box)
        end
    end

    return box_set
end

function _try_cut_comb_partition(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    g_boxes::Vector{Int},
)::Union{Nothing,CutCombSubdiagramProof}
    return _try_cut_comb_partition(_comb_diagram_index(wd), witness, g_boxes)
end

function _try_cut_comb_partition(
    index::CombDiagramIndex,
    witness::CombWitness,
    g_boxes::Vector{Int},
)::Union{Nothing,CutCombSubdiagramProof}
    g_set = Set(g_boxes)

    isempty(g_boxes) && return nothing
    length(g_set) == length(g_boxes) || return nothing
    all(b -> b in index.internal_set, g_boxes) || return nothing

    f_boxes = setdiff(index.internal_boxes, g_boxes)
    isempty(f_boxes) && return nothing

    g_boundary, f_boundary = _partition_boundaries_unchecked(index, g_set, Set(f_boxes))
    boundary_matches(g_boundary; inputs=witness.A, outputs=witness.B) || return nothing

    expected_f_outputs = vcat(witness.A, witness.C)
    boundary_matches(f_boundary; inputs=witness.B, outputs=expected_f_outputs) || return nothing

    g_proof = CombSubdiagramProof(witness, sort(g_boxes), g_boundary)
    f_proof = FSubdiagramProof(witness, f_boxes, f_boundary)
    return CutCombSubdiagramProof(witness, g_proof, f_proof)
end

function _find_complete_cut_comb_partition(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::Union{Nothing,CutCombSubdiagramProof}
    internal_boxes = _internal_box_ids(wd)
    length(internal_boxes) >= 2 || return nothing
    length(internal_boxes) <= 24 || return nothing

    current = Int[]
    found = Ref{Union{Nothing,CutCombSubdiagramProof}}(nothing)

    function search(i::Int)
        found[] !== nothing && return

        if i > length(internal_boxes)
            if isempty(current) || length(current) == length(internal_boxes)
                return
            end

            proof = _try_cut_comb_partition(wd, state, witness, sort(copy(current)))
            proof === nothing || (found[] = proof)
            return
        end

        push!(current, internal_boxes[i])
        search(i + 1)
        pop!(current)
        search(i + 1)
    end

    search(1)
    return found[]
end

function candidate_g_boxes(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::Vector{Int}
    return candidate_g_boxes(wd, state, witness, _comb_diagram_index(wd))
end

function candidate_g_boxes(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    index::CombDiagramIndex,
)::Vector{Int}
    b_set = Set(witness.B)

    # The g-region must expose B at its output boundary. For state-like comb
    # diagrams, B appears as an external diagram output, so start from wires
    # feeding those output ports. This avoids scanning every box's output ports
    # on large diagrams.
    box_set = Set{Int}()
    b_output_ports = Set{Int}()
    for b in witness.B
        for port in get(index.output_ports_by_var, b, Int[])
            push!(b_output_ports, port)
        end
    end
    output_box = output_id(wd)
    for w in index.wires
        w.target.box == output_box || continue
        w.target.port in b_output_ports || continue
        w.source.box > 0 && push!(box_set, w.source.box)
    end

    # Fallback for diagrams where B is not exposed as an external output.
    if isempty(box_set)
        for b in index.internal_boxes
            outputs = _symbol_port_values(wd, b, OutputPort)
            any(v -> v in b_set, outputs) || continue
            push!(box_set, b)
        end
    end

    # Close the g-region backwards over non-A inputs. This includes exogenous
    # source boxes such as PU_PBC -> f_PBC, and hidden/internal preprocessing
    # boxes in a multi-box g-region, while preserving A as the external
    # boundary of g.
    _close_backward_over_nonboundary_inputs!(index, box_set, Set(witness.A))

    return sort(collect(box_set))
end

function candidate_g_boxes_graph(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
)::Vector{Int}
    observed = Set(variable_names(state.variables))
    graph = extract_variable_graph(wd; observed=observed)
    reachable_from_A = _nodes_reachable_from(graph, witness.A)
    reaches_B = _nodes_that_reach(graph, witness.B)
    g_region_vars = intersect(reachable_from_A, reaches_B)
    setdiff!(g_region_vars, Set(witness.B))

    boxes = Int[]
    allowed_g_inputs = union(g_region_vars, Set(witness.A), Set(witness.B))
    for b in _internal_box_ids(wd)
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

    box_set = Set(boxes)
    a_set = Set(witness.A)
    _close_backward_over_nonboundary_inputs!(wd, box_set, a_set)

    return sort(collect(box_set))
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

function prove_g_subdiagram(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    g_boxes::Vector{Int},
)::CombSubdiagramProof
    validate_comb_witness(wd, state, witness)

    return _prove_g_subdiagram_checked(wd, witness, g_boxes)
end

function _prove_g_subdiagram_checked(
    wd::WiringDiagram,
    witness::CombWitness,
    g_boxes::Vector{Int},
)::CombSubdiagramProof
    isempty(g_boxes) && error("could not prove g subdiagram: explicit g_boxes is empty")
    g_boundary = _subdiagram_boundary_unchecked(wd, Set(g_boxes))
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

function prove_f_subdiagram(
    wd::WiringDiagram,
    state::JointState,
    witness::CombWitness,
    g_proof::CombSubdiagramProof,
    f_boxes::Vector{Int},
)::FSubdiagramProof
    validate_comb_witness(wd, state, witness)

    return _prove_f_subdiagram_checked(wd, witness, g_proof, f_boxes)
end

function _prove_f_subdiagram_checked(
    wd::WiringDiagram,
    witness::CombWitness,
    g_proof::CombSubdiagramProof,
    f_boxes::Vector{Int},
)::FSubdiagramProof
    isempty(f_boxes) && error("could not prove f subdiagram: explicit f_boxes is empty")
    f_boundary = _subdiagram_boundary_unchecked(wd, Set(f_boxes))
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
    index = _comb_diagram_index(wd)
    validate_comb_witness(index, state, witness)

    fast_g_boxes = candidate_g_boxes(wd, state, witness, index)
    fast_proof = _try_cut_comb_partition(index, witness, fast_g_boxes)
    fast_proof === nothing || return fast_proof

    graph_g_boxes = candidate_g_boxes_graph(wd, state, witness)
    graph_proof = _try_cut_comb_partition(index, witness, graph_g_boxes)
    graph_proof === nothing || return graph_proof

    complete_proof = _find_complete_cut_comb_partition(wd, state, witness)
    complete_proof === nothing &&
        error("could not prove cut-comb subdiagrams: no partition of internal boxes satisfies g : $(witness.A) -> $(witness.B) and f : $(witness.B) -> $(vcat(witness.A, witness.C))")

    return complete_proof
end

function prove_cut_comb_subdiagrams(
    wd::WiringDiagram,
    state::JointState,
    structure::CombStructure,
)::CutCombSubdiagramProof
    witness = structure.witness

    (structure.g_boxes === nothing) == (structure.f_boxes === nothing) ||
        error("provide both g_boxes and f_boxes, or provide neither")

    if structure.g_boxes === nothing
        return prove_cut_comb_subdiagrams(wd, state, witness)
    end

    g_proof = prove_g_subdiagram(wd, state, witness, resolve_box_ids(wd, structure.g_boxes))

    f_proof = prove_f_subdiagram(wd, state, witness, g_proof, resolve_box_ids(wd, structure.f_boxes))

    overlap = intersect(Set(g_proof.g_boxes), Set(f_proof.f_boxes))
    isempty(overlap) ||
        error("could not prove cut-comb subdiagrams: g and f boxes overlap: $(sort(collect(overlap)))")

    if structure.cover_all_boxes
        internal_boxes = Set(b for b in box_ids(wd) if b > 0)
        covered_boxes = union(Set(g_proof.g_boxes), Set(f_proof.f_boxes))
        missing = setdiff(internal_boxes, covered_boxes)
        extra = setdiff(covered_boxes, internal_boxes)
        isempty(missing) ||
            error("could not prove complete comb structure: boxes not covered by g/f: $(sort(collect(missing)))")
        isempty(extra) ||
            error("could not prove complete comb structure: unknown boxes in g/f: $(sort(collect(extra)))")
    end

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

function validate_comb_witness(
    index::CombDiagramIndex,
    state::JointState,
    witness::CombWitness,
)
    state_vars = Set(variable_names(state.variables))
    witness_vars = Set(vcat(witness.A, witness.B, witness.C))

    missing_in_diagram = setdiff(witness_vars, index.diagram_vars)
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
    wd = WiringDiagram(Any[witness.A...], Any[witness.C...])

    g_box = add_box!(wd, Box(:g_comb, Any[witness.A...], Any[witness.B...]))
    f_box = add_box!(wd, Box(:f_cut, Any[witness.B...], Any[witness.C...]))

    for (i, _) in enumerate(witness.A)
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
    comb_structure::Union{Nothing,CombStructure}=nothing,
    witness::Union{Nothing,CombWitness}=nothing,
    intervention::Union{Nothing,Vector{Symbol}}=nothing,
    context::Union{Nothing,Vector{Symbol}}=nothing,
    bridge::Union{Nothing,Vector{Symbol}}=nothing,
    outcome::Union{Nothing,Vector{Symbol}}=nothing,
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
    validate_reconstruction::Bool=true,
)::CombOnlyCausalEffectResult
    local resolved_witness::CombWitness
    try
        if comb_structure !== nothing
            (witness !== nothing || intervention !== nothing || context !== nothing || bridge !== nothing || outcome !== nothing) &&
                error("provide either comb_structure or witness/intervention/bridge/outcome, not both")
            resolved_witness = comb_structure.witness
            validate_comb_witness(wd, state, resolved_witness)
            subdiagram_proof = prove_cut_comb_subdiagrams(wd, state, comb_structure)
        elseif witness === nothing
            intervention === nothing && error("either witness or intervention/bridge/outcome must be provided")
            outcome === nothing && error("either witness or intervention/bridge/outcome must be provided")
            if bridge === nothing
                discovered = discover_comb_witness(
                    wd,
                    state;
                    intervention=intervention,
                    outcome=outcome,
                )
                context_vars = context === nothing ? Symbol[] : context
                resolved_witness = isempty(context_vars) ? discovered : CombWitness(
                    A=vcat(context_vars, intervention),
                    B=discovered.B,
                    C=outcome,
                    intervention=intervention,
                    context=context_vars,
                )
            else
                context_vars = context === nothing ? Symbol[] : context
                input_vars = vcat(context_vars, intervention)
                resolved_witness = CombWitness(
                    A=input_vars,
                    B=bridge,
                    C=outcome,
                    intervention=intervention,
                    context=context_vars,
                )
            end
        else
            resolved_witness = witness
        end

        if comb_structure === nothing
            validate_comb_witness(wd, state, resolved_witness)
            subdiagram_proof = prove_cut_comb_subdiagrams(wd, state, resolved_witness)
        end

        markov = validate_markov_property(wd, state)
        if !markov.passed
            if markov.error !== nothing
                error("Markov validation failed: $(markov.error)")
            end
            details = join(
                [
                    "$(f.variable) ⟂ $(f.independent_of) | $(f.given) violated by $(round(f.max_abs_diff; sigdigits=4))"
                    for f in markov.failures
                ],
                "; ",
            )
            error("Markov validation failed: $(details)")
        end

        base = infer_causal_effect(
            state;
            A=resolved_witness.A,
            B=resolved_witness.B,
            C=resolved_witness.C,
            context=resolved_witness.context,
            intervention=resolved_witness.intervention,
            require_full_support=require_full_support,
            reconstruction_atol=reconstruction_atol,
            validate_reconstruction=validate_reconstruction,
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
        fallback_witness = if comb_structure !== nothing
            comb_structure.witness
        elseif witness !== nothing
            witness
        else
            CombWitness(Symbol[:__invalid__], Symbol[], Symbol[], Symbol[:__invalid__])
        end
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
