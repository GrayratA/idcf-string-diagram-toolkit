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
