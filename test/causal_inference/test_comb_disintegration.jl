@testset "comb disintegration" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2)
    probs[1, 1, 1] = 0.50  # S=0, T=0, C=0
    probs[1, 1, 2] = 0.10  # S=0, T=0, C=1
    probs[1, 2, 1] = 0.01  # S=0, T=1, C=0
    probs[1, 2, 2] = 0.02  # S=0, T=1, C=1
    probs[2, 1, 1] = 0.10  # S=1, T=0, C=0
    probs[2, 1, 2] = 0.05  # S=1, T=0, C=1
    probs[2, 2, 1] = 0.02  # S=1, T=1, C=0
    probs[2, 2, 2] = 0.20  # S=1, T=1, C=1
    state = JointState([S, T, C], probs)

    comb = comb_disintegrate(state; A=[:S], B=[:T], C=[:C])

    @test comb.A == [S]
    @test comb.B == [T]
    @test comb.C == [C]
    @test comb.g.inputs == [S]
    @test comb.g.outputs == [T]
    @test comb.f.inputs == [T]
    @test comb.f.outputs == [S, C]

    reconstructed = reconstruct_joint(comb)
    @test reconstructed.variables == [S, T, C]
    @test reconstructed.probabilities ≈ state.probabilities

    c_do_s = cut_comb(comb)
    @test c_do_s.inputs == [S]
    @test c_do_s.outputs == [C]

    # Smoking example values:
    # P(C=1 | do(S=0)) ≈ 0.25347763
    # P(C=1 | do(S=1)) ≈ 0.54229730
    @test c_do_s.probabilities[:, 1] ≈ [0.74652237, 0.25347763] atol=1e-8
    @test c_do_s.probabilities[:, 2] ≈ [0.45770270, 0.54229730] atol=1e-8
end

@testset "context-aware comb disintegration" begin
    A = FiniteVariable(:A, [0, 1])
    X = FiniteVariable(:X, [0, 1])
    B = FiniteVariable(:B, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2, 2)
    for idx in CartesianIndices(probs)
        a, x, b, c = Tuple(idx) .- 1
        probs[idx] = 1.0 + 0.7a + 0.5x + 0.3b + 0.2c + 0.4a * b + 0.6x * c
    end
    probs ./= sum(probs)
    state = JointState([A, X, B, C], probs)

    effect = cut_comb_direct_context(
        state;
        context=[:A],
        intervention=[:X],
        B=[:B],
        C=[:C],
    )

    manual = zeros(Float64, 2, 2, 2)
    for a in 1:2
        p_a = sum(probs[a, :, :, :])
        for x in 1:2
            p_ax = sum(probs[a, x, :, :])
            for b in 1:2
                p_b_given_ax = sum(probs[a, x, b, :]) / p_ax
                p_c_do_b_given_a = zeros(Float64, 2)
                for xp in 1:2
                    p_xp_given_a = sum(probs[a, xp, :, :]) / p_a
                    denom = sum(probs[a, xp, b, :])
                    for c in 1:2
                        p_c_do_b_given_a[c] += p_xp_given_a * probs[a, xp, b, c] / denom
                    end
                end
                for c in 1:2
                    manual[c, a, x] += p_b_given_ax * p_c_do_b_given_a[c]
                end
            end
        end
    end

    @test effect.inputs == [A, X]
    @test effect.outputs == [C]
    @test effect.probabilities ≈ manual
    @test all(sum(effect.probabilities; dims=1) .≈ 1.0)
end
