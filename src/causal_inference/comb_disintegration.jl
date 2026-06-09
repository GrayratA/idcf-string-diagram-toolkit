"""
Comb-disintegration primitives for finite-discrete causal inference.

For a joint state P(A,B,C), `comb_disintegrate` constructs

    g : A -> B
    f : B -> A ⊗ C

where

    g(b | a) = P(b | a)
    f(a,c | b) = P(a) P(c | a,b)
"""

struct TwoComb
    A::Vector{FiniteVariable}
    B::Vector{FiniteVariable}
    C::Vector{FiniteVariable}
    f::StochChannel
    g::StochChannel
end

function _check_disjoint_groups(A::Vector{Symbol}, B::Vector{Symbol}, C::Vector{Symbol})
    all_names = vcat(A, B, C)
    length(unique(all_names)) == length(all_names) ||
        error("A, B, and C variable groups must be pairwise disjoint")
end

function _check_disjoint_groups(A::Vector{Symbol}, X::Vector{Symbol}, B::Vector{Symbol}, C::Vector{Symbol})
    all_names = vcat(A, X, B, C)
    length(unique(all_names)) == length(all_names) ||
        error("context, intervention, B, and C variable groups must be pairwise disjoint")
end

function _full_support(state::JointState; atol::Float64=1e-12)::Bool
    return all(state.probabilities .> atol)
end

"""
Construct the two-comb associated with the variable split `(A,B,C)`.

`A`, `B`, and `C` can each contain multiple variables. Internally, each group
is treated as a tensor product in the order supplied by the caller.
"""
function comb_disintegrate(
    state::JointState;
    A::Vector{Symbol},
    B::Vector{Symbol},
    C::Vector{Symbol},
    require_full_support::Bool=true,
)::TwoComb
    _check_disjoint_groups(A, B, C)

    ordered_state = marginal(state, vcat(A, B, C))
    if require_full_support && !_full_support(ordered_state)
        error("comb disintegration requires full support for P(A,B,C)")
    end

    A_vars = _variables_by_name(ordered_state.variables, A)
    B_vars = _variables_by_name(ordered_state.variables, B)
    C_vars = _variables_by_name(ordered_state.variables, C)

    p_A = marginal(ordered_state, A)
    g = conditional(ordered_state, B, A)
    c_given_ab = conditional(ordered_state, C, vcat(A, B))

    A_dims = Tuple(length(v.values) for v in A_vars)
    B_dims = Tuple(length(v.values) for v in B_vars)
    C_dims = Tuple(length(v.values) for v in C_vars)

    A_indices = isempty(A_vars) ? [CartesianIndex()] : CartesianIndices(A_dims)
    B_indices = isempty(B_vars) ? [CartesianIndex()] : CartesianIndices(B_dims)
    C_indices = isempty(C_vars) ? [CartesianIndex()] : CartesianIndices(C_dims)

    f_probs = zeros(Float64, A_dims..., C_dims..., B_dims...)
    for b_idx in B_indices
        for a_idx in A_indices
            p_a = p_A.probabilities[Tuple(a_idx)...]
            for c_idx in C_indices
                p_c_given_ab = c_given_ab.probabilities[
                    Tuple(c_idx)...,
                    Tuple(a_idx)...,
                    Tuple(b_idx)...,
                ]
                f_probs[Tuple(a_idx)..., Tuple(c_idx)..., Tuple(b_idx)...] =
                    p_a * p_c_given_ab
            end
        end
    end

    f = StochChannel(B_vars, vcat(A_vars, C_vars), f_probs)
    return TwoComb(A_vars, B_vars, C_vars, f, g)
end

"""
Reconstruct P(A,B,C) from a two-comb.
"""
function reconstruct_joint(comb::TwoComb)::JointState
    A_vars, B_vars, C_vars = comb.A, comb.B, comb.C
    A_dims = Tuple(length(v.values) for v in A_vars)
    B_dims = Tuple(length(v.values) for v in B_vars)
    C_dims = Tuple(length(v.values) for v in C_vars)

    A_indices = isempty(A_vars) ? [CartesianIndex()] : CartesianIndices(A_dims)
    B_indices = isempty(B_vars) ? [CartesianIndex()] : CartesianIndices(B_dims)
    C_indices = isempty(C_vars) ? [CartesianIndex()] : CartesianIndices(C_dims)

    probs = zeros(Float64, A_dims..., B_dims..., C_dims...)
    for a_idx in A_indices
        for b_idx in B_indices
            p_b_given_a = comb.g.probabilities[Tuple(b_idx)..., Tuple(a_idx)...]
            for c_idx in C_indices
                p_a_c_given_b = comb.f.probabilities[
                    Tuple(a_idx)...,
                    Tuple(c_idx)...,
                    Tuple(b_idx)...,
                ]
                probs[Tuple(a_idx)..., Tuple(b_idx)..., Tuple(c_idx)...] =
                    p_b_given_a * p_a_c_given_b
            end
        end
    end

    return JointState(vcat(A_vars, B_vars, C_vars), probs)
end

"""
Cut the comb at A and return the interventional channel A -> C.

This computes

    P(c | do(a)) = Σ_b P(b | a) Σ_a' f(a', c | b).
"""
function cut_comb(comb::TwoComb)::StochChannel
    A_vars, B_vars, C_vars = comb.A, comb.B, comb.C
    A_dims = Tuple(length(v.values) for v in A_vars)
    B_dims = Tuple(length(v.values) for v in B_vars)
    C_dims = Tuple(length(v.values) for v in C_vars)

    A_indices = isempty(A_vars) ? [CartesianIndex()] : CartesianIndices(A_dims)
    B_indices = isempty(B_vars) ? [CartesianIndex()] : CartesianIndices(B_dims)
    C_indices = isempty(C_vars) ? [CartesianIndex()] : CartesianIndices(C_dims)

    f_cut_probs = zeros(Float64, C_dims..., B_dims...)
    for b_idx in B_indices
        for c_idx in C_indices
            total = 0.0
            for a_idx in A_indices
                total += comb.f.probabilities[
                    Tuple(a_idx)...,
                    Tuple(c_idx)...,
                    Tuple(b_idx)...,
                ]
            end
            f_cut_probs[Tuple(c_idx)..., Tuple(b_idx)...] = total
        end
    end

    f_cut = StochChannel(B_vars, C_vars, f_cut_probs)
    return compose_channels(comb.g, f_cut)
end

"""
Compute the cut-comb effect directly from `P(A,B,C)`.

This is the fast numerical path for

    P(c | do(a)) = Σ_b P(b | a) Σ_a' P(a') P(c | a', b).

It avoids constructing the full `f : B -> A ⊗ C` channel and avoids the
optional reconstruction check used by the slower diagnostic path.
"""
function cut_comb_direct(
    state::JointState;
    A::Vector{Symbol},
    B::Vector{Symbol},
    C::Vector{Symbol},
    require_full_support::Bool=true,
    atol::Float64=1e-12,
)::StochChannel
    _check_disjoint_groups(A, B, C)

    ordered_state = marginal(state, vcat(A, B, C))
    if require_full_support && !_full_support(ordered_state; atol=atol)
        error("comb disintegration requires full support for P(A,B,C)")
    end

    A_vars = _variables_by_name(ordered_state.variables, A)
    B_vars = _variables_by_name(ordered_state.variables, B)
    C_vars = _variables_by_name(ordered_state.variables, C)

    A_dims = Tuple(length(v.values) for v in A_vars)
    B_dims = Tuple(length(v.values) for v in B_vars)
    C_dims = Tuple(length(v.values) for v in C_vars)

    A_indices = isempty(A_vars) ? [CartesianIndex()] : CartesianIndices(A_dims)
    B_indices = isempty(B_vars) ? [CartesianIndex()] : CartesianIndices(B_dims)
    C_indices = isempty(C_vars) ? [CartesianIndex()] : CartesianIndices(C_dims)

    p_A = zeros(Float64, A_dims...)
    p_AB = zeros(Float64, A_dims..., B_dims...)

    probs = ordered_state.probabilities
    for a_idx in A_indices
        a_tuple = Tuple(a_idx)
        for b_idx in B_indices
            b_tuple = Tuple(b_idx)
            total_ab = 0.0
            for c_idx in C_indices
                total_ab += probs[a_tuple..., b_tuple..., Tuple(c_idx)...]
            end
            p_AB[a_tuple..., b_tuple...] = total_ab
            p_A[a_tuple...] += total_ab
        end
    end

    c_do_b = zeros(Float64, C_dims..., B_dims...)
    for b_idx in B_indices
        b_tuple = Tuple(b_idx)
        for c_idx in C_indices
            c_tuple = Tuple(c_idx)
            total = 0.0
            for a_idx in A_indices
                a_tuple = Tuple(a_idx)
                p_ab = p_AB[a_tuple..., b_tuple...]
                p_ab > atol || error("conditioning event for A=$(a_tuple), B=$(b_tuple) has probability $(p_ab)")
                total += p_A[a_tuple...] * probs[a_tuple..., b_tuple..., c_tuple...] / p_ab
            end
            c_do_b[c_tuple..., b_tuple...] = total
        end
    end

    effect_probs = zeros(Float64, C_dims..., A_dims...)
    for a_idx in A_indices
        a_tuple = Tuple(a_idx)
        p_a = p_A[a_tuple...]
        p_a > atol || error("conditioning event for A=$(a_tuple) has probability $(p_a)")
        for c_idx in C_indices
            c_tuple = Tuple(c_idx)
            total = 0.0
            for b_idx in B_indices
                b_tuple = Tuple(b_idx)
                p_b_given_a = p_AB[a_tuple..., b_tuple...] / p_a
                total += p_b_given_a * c_do_b[c_tuple..., b_tuple...]
            end
            effect_probs[c_tuple..., a_tuple...] = total
        end
    end

    return StochChannel(A_vars, C_vars, effect_probs)
end

"""
Compute the context-aware cut-comb effect directly from `P(A,X,B,C)`.

This implements the Section-8-style finite formula

    P(c | a, do(x)) =
        Σ_b P(b | a,x) Σ_x' P(x' | a) P(c | a,x',b).

`context` is the non-intervened background input `A`; `intervention` is `X`.
When `context` is empty this reduces to the existing cut-comb formula.
"""
function cut_comb_direct_context(
    state::JointState;
    context::Vector{Symbol},
    intervention::Vector{Symbol},
    B::Vector{Symbol},
    C::Vector{Symbol},
    require_full_support::Bool=true,
    atol::Float64=1e-12,
)::StochChannel
    _check_disjoint_groups(context, intervention, B, C)

    isempty(context) && return cut_comb_direct(
        state;
        A=intervention,
        B=B,
        C=C,
        require_full_support=require_full_support,
        atol=atol,
    )

    ordered_state = marginal(state, vcat(context, intervention, B, C))
    if require_full_support && !_full_support(ordered_state; atol=atol)
        error("context comb disintegration requires full support for P(A,X,B,C)")
    end

    A_vars = _variables_by_name(ordered_state.variables, context)
    X_vars = _variables_by_name(ordered_state.variables, intervention)
    B_vars = _variables_by_name(ordered_state.variables, B)
    C_vars = _variables_by_name(ordered_state.variables, C)

    A_dims = Tuple(length(v.values) for v in A_vars)
    X_dims = Tuple(length(v.values) for v in X_vars)
    B_dims = Tuple(length(v.values) for v in B_vars)
    C_dims = Tuple(length(v.values) for v in C_vars)

    A_indices = isempty(A_vars) ? [CartesianIndex()] : CartesianIndices(A_dims)
    X_indices = isempty(X_vars) ? [CartesianIndex()] : CartesianIndices(X_dims)
    B_indices = isempty(B_vars) ? [CartesianIndex()] : CartesianIndices(B_dims)
    C_indices = isempty(C_vars) ? [CartesianIndex()] : CartesianIndices(C_dims)

    probs = ordered_state.probabilities
    p_A = zeros(Float64, A_dims...)
    p_AX = zeros(Float64, A_dims..., X_dims...)
    p_AXB = zeros(Float64, A_dims..., X_dims..., B_dims...)

    for a_idx in A_indices
        a_tuple = Tuple(a_idx)
        for x_idx in X_indices
            x_tuple = Tuple(x_idx)
            total_ax = 0.0
            for b_idx in B_indices
                b_tuple = Tuple(b_idx)
                total_axb = 0.0
                for c_idx in C_indices
                    total_axb += probs[a_tuple..., x_tuple..., b_tuple..., Tuple(c_idx)...]
                end
                p_AXB[a_tuple..., x_tuple..., b_tuple...] = total_axb
                total_ax += total_axb
            end
            p_AX[a_tuple..., x_tuple...] = total_ax
            p_A[a_tuple...] += total_ax
        end
    end

    c_do_b_given_a = zeros(Float64, C_dims..., A_dims..., B_dims...)
    for a_idx in A_indices
        a_tuple = Tuple(a_idx)
        p_a = p_A[a_tuple...]
        p_a > atol || error("conditioning event for context A=$(a_tuple) has probability $(p_a)")
        for b_idx in B_indices
            b_tuple = Tuple(b_idx)
            for c_idx in C_indices
                c_tuple = Tuple(c_idx)
                total = 0.0
                for xprime_idx in X_indices
                    xprime_tuple = Tuple(xprime_idx)
                    p_ax = p_AX[a_tuple..., xprime_tuple...]
                    p_axb = p_AXB[a_tuple..., xprime_tuple..., b_tuple...]
                    p_ax > atol || error("conditioning event for A=$(a_tuple), X=$(xprime_tuple) has probability $(p_ax)")
                    p_axb > atol || error("conditioning event for A=$(a_tuple), X=$(xprime_tuple), B=$(b_tuple) has probability $(p_axb)")
                    p_x_given_a = p_ax / p_a
                    p_c_given_axb = probs[a_tuple..., xprime_tuple..., b_tuple..., c_tuple...] / p_axb
                    total += p_x_given_a * p_c_given_axb
                end
                c_do_b_given_a[c_tuple..., a_tuple..., b_tuple...] = total
            end
        end
    end

    effect_probs = zeros(Float64, C_dims..., A_dims..., X_dims...)
    for a_idx in A_indices
        a_tuple = Tuple(a_idx)
        for x_idx in X_indices
            x_tuple = Tuple(x_idx)
            p_ax = p_AX[a_tuple..., x_tuple...]
            p_ax > atol || error("conditioning event for A=$(a_tuple), X=$(x_tuple) has probability $(p_ax)")
            for c_idx in C_indices
                c_tuple = Tuple(c_idx)
                total = 0.0
                for b_idx in B_indices
                    b_tuple = Tuple(b_idx)
                    p_b_given_ax = p_AXB[a_tuple..., x_tuple..., b_tuple...] / p_ax
                    total += p_b_given_ax * c_do_b_given_a[c_tuple..., a_tuple..., b_tuple...]
                end
                effect_probs[c_tuple..., a_tuple..., x_tuple...] = total
            end
        end
    end

    return StochChannel(vcat(A_vars, X_vars), C_vars, effect_probs)
end
