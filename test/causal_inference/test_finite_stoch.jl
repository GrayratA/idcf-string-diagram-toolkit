@testset "finite stochastic primitives" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    # Smoking example distribution in variable order S, T, C.
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

    @test variable_names(state.variables) == [:S, :T, :C]

    p_s = marginal(state, [:S])
    @test p_s.probabilities ≈ [0.63, 0.37]

    p_c_s = marginal(state, [:C, :S])
    @test p_c_s.probabilities ≈ [0.51 0.12; 0.12 0.25]

    c_given_s = conditional(state, [:C], [:S])
    @test c_given_s.inputs == [S]
    @test c_given_s.outputs == [C]
    @test c_given_s.probabilities[:, 1] ≈ [0.51 / 0.63, 0.12 / 0.63]
    @test c_given_s.probabilities[:, 2] ≈ [0.12 / 0.37, 0.25 / 0.37]

    t_given_s = conditional(state, [:T], [:S])
    c_given_t = conditional(state, [:C], [:T])
    c_given_s_via_t = compose_channels(t_given_s, c_given_t)

    @test c_given_s_via_t.inputs == [S]
    @test c_given_s_via_t.outputs == [C]
    @test all(sum(c_given_s_via_t.probabilities; dims=1) .≈ 1.0)
end
