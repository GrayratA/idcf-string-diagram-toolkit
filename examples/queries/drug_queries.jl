(
    name="drug_three_world",
    queries=[
        CounterfactualQuery(
            :World1,
            Dict(:X => :x),
            Dict{Symbol, Symbol}(),
            [:Y],
        ),
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
    ],
    rules=(
        enabled=true,
        directed_edges=[("X", "W"), ("W", "Y"), ("Z", "Y"), ("D", "Z")],
    ),
    display=(
        symbols=Dict("Y" => "y", "W" => "w", "D" => "d", "Z" => "z", "X" => "x"),
        value_rename=Dict("x_hat" => "x'"),
    ),
    data=(
        mode=:interventions,
        mix_var="D",
        mix_sym="d^*",
        mix_target_var="Z",
        anchor_var="X",
    ),
)
