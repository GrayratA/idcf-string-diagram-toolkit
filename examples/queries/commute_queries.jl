(
    name="commute_three_world",
    queries=[
        CounterfactualQuery(
            :World1,
            Dict(:T => :t),
            Dict{Symbol, Symbol}(),
            [:Y],
        ),
        CounterfactualQuery(
            :World2,
            Dict{Symbol, Symbol}(),
            Dict(:W => :w, :T => :t_),
            Symbol[],
        ),
        CounterfactualQuery(
            :World3,
            Dict(:W => :w),
            Dict(:M => :m),
            Symbol[],
        ),
    ],
    rules=(
        enabled=true,
        directed_edges=[("W", "T"), ("W", "M"), ("T", "L"), ("M", "L"), ("L", "Y")],
    ),
    display=(
        symbols=Dict("W" => "w", "T" => "t", "M" => "m", "L" => "l", "Y" => "y"),
        value_rename=Dict("t_" => "t'"),
    ),
    data=(
        mode=:interventions,
        mix_var="W",
        mix_sym="w^*",
        anchor_var="W",
        anchor_token="w",
    ),
)
