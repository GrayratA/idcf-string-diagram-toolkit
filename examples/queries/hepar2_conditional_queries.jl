(
    name="hepar2_three_world_conditional",
    queries=[
        CounterfactualQuery(
            :Real,
            Dict{Symbol, Symbol}(),
            Dict(:age => :age_obs, :sex => :sex_obs),
            Symbol[],
        ),
        CounterfactualQuery(
            :CF_pbc,
            Dict(:age => :age_do),
            Dict(:pbc => :pbc_obs),
            Symbol[],
        ),
        CounterfactualQuery(
            :CF_carc,
            Dict(:age => :age_do),
            Dict(:carcinoma => :carc_obs),
            Symbol[],
        ),
    ],
    display_syms=[:age, :sex, :pbc, :carcinoma],
    output_vars=["carcinoma"],
    display=(
        symbols=Dict(
            "age" => "age",
            "sex" => "sex",
            "pbc" => "pbc",
            "carcinoma" => "carcinoma",
        ),
        value_rename=Dict("age_do" => "age"),
    ),
    data=(mode=:conditional_queries,),
)
