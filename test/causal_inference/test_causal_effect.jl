@testset "causal effect interface" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2)
    probs[1, 1, 1] = 0.50
    probs[1, 1, 2] = 0.10
    probs[1, 2, 1] = 0.01
    probs[1, 2, 2] = 0.02
    probs[2, 1, 1] = 0.10
    probs[2, 1, 2] = 0.05
    probs[2, 2, 1] = 0.02
    probs[2, 2, 2] = 0.20
    state = JointState([S, T, C], probs)

    result = infer_causal_effect(state; A=[:S], B=[:T], C=[:C])

    @test result.computable
    @test result.failure_reason === nothing
    @test result.reconstruction_ok
    @test result.effect !== nothing
    @test result.comb !== nothing
    @test result.reconstructed !== nothing
    @test result.effect.probabilities[:, 1] ≈ [0.74652237, 0.25347763] atol=1e-8
    @test result.effect.probabilities[:, 2] ≈ [0.45770270, 0.54229730] atol=1e-8

    zero_support_probs = copy(probs)
    zero_support_probs[1, 2, 1] = 0.0
    zero_support_probs .*= 1.0 / sum(zero_support_probs)
    zero_support_state = JointState([S, T, C], zero_support_probs)

    failed = infer_causal_effect(zero_support_state; A=[:S], B=[:T], C=[:C])
    @test !failed.computable
    @test failed.effect === nothing
    @test occursin("full support", failed.failure_reason)
end
