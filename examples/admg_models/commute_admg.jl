(
    name="commute_admg",
    input=ADMGModel(
        [
            :W => :T,
            :W => :M,
            :T => :L,
            :M => :L,
            :L => :Y,
        ],
        [
            :T => :Y,
        ],
    ),
    display_syms=[:W, :T, :M, :L, :Y],
    output_vars=["Y"],
)
