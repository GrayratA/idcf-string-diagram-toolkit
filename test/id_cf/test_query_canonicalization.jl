@testset "query canonicalization" begin
    q_real_1 = CounterfactualQuery(:B, Dict{Symbol,Symbol}(), Dict(:X => :x1), Symbol[])
    q_real_2 = CounterfactualQuery(:A, Dict{Symbol,Symbol}(), Dict(:D => :d), Symbol[])
    q_ev = CounterfactualQuery(:ZWorld, Dict(:D => :d), Dict(:Z => :z), Symbol[])
    q_target = CounterfactualQuery(:Target, Dict(:X => :x), Dict{Symbol,Symbol}(), [:Y])

    qs = canonicalize_counterfactual_queries([q_real_1, q_ev, q_target, q_real_2])

    @test length(qs) == 2
    @test qs[1].outputs == [:Y]
    @test qs[2].world_name == :Real
    @test qs[2].interventions == Dict{Symbol,Symbol}()
    @test qs[2].observations == Dict(:X => :x1, :D => :d, :Z => :z)
end

@testset "semantic query normalization" begin
    model = ADMGModel(
        [
            :D => :Z,
            :Z => :Y,
            :W => :Y,
        ],
        Pair{Symbol,Symbol}[],
    )

    q_target = CounterfactualQuery(:Target, Dict(:D => :d, :Unused => :u), Dict{Symbol,Symbol}(), [:Y])
    q_real = CounterfactualQuery(:Observed, Dict{Symbol,Symbol}(), Dict(:D => :d), Symbol[])
    q_ev = CounterfactualQuery(:Evidence, Dict(:D => :d), Dict(:Z => :z), Symbol[])

    norm = normalize_counterfactual_query(model, [q_ev, q_target, q_real]; apply_consistency=true)

    @test isempty(norm.contradictions)
    @test length(norm.queries) == 2
    @test norm.queries[1].outputs == [:Y]
    @test norm.queries[1].interventions == Dict{Symbol,Symbol}()
    @test norm.queries[2].world_name == :Real
    @test norm.queries[2].observations == Dict(:D => :d, :Z => :z)
end

@testset "semantic normalization detects contradictions" begin
    qs = [
        CounterfactualQuery(:Real1, Dict{Symbol,Symbol}(), Dict(:X => :x), Symbol[]),
        CounterfactualQuery(:Real2, Dict{Symbol,Symbol}(), Dict(:X => :x2), Symbol[]),
    ]

    res = identify_counterfactual(
        ADMGModel([:X => :Y], Pair{Symbol,Symbol}[]),
        qs;
        display_syms=[:X, :Y],
        output_vars=["Y"],
        trace_dir=nothing,
    )

    @test !res.identifiable
    @test res.failure_stage == :normalize
    @test occursin("Conflicting factual observations", res.error)
end

@testset "drug query order is canonicalized" begin
    model = ADMGModel(
        [
            :X => :W,
            :W => :Y,
            :D => :Z,
            :Z => :Y,
        ],
        [
            :X => :Y,
        ],
    )

    bad_order_queries = [
        CounterfactualQuery(
            :World2,
            Dict{Symbol, Symbol}(),
            Dict(:X => :x_hat, :D => :d),
            Symbol[],
        ),
        CounterfactualQuery(
            :World3,
            Dict(:D => :d),
            Dict(:Z => :z),
            Symbol[],
        ),
        CounterfactualQuery(
            :World1,
            Dict(:X => :x),
            Dict{Symbol, Symbol}(),
            [:Y],
        ),
    ]

    res = identify_counterfactual(
        model,
        bad_order_queries;
        display_syms=[:D, :Z, :X, :W, :Y],
        output_vars=["Y"],
        trace_dir=nothing,
    )

    @test res.identifiable
    @test res.failure_stage === nothing
    @test isempty(res.step3_blockers)
end
