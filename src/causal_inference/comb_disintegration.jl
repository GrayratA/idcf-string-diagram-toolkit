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
