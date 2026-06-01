using Catlab

include(joinpath(@__DIR__, "admg_compile.jl"))
include(joinpath(@__DIR__, "bn_import.jl"))
include(joinpath(@__DIR__, "simplify_cf.jl"))
include(joinpath(@__DIR__, "id_cf.jl"))
include(joinpath(@__DIR__, "chyp_export.jl"))

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

default_diagram_file() = joinpath(REPO_ROOT, "examples", "string_diagrams", "commute_scm.jl")
default_query_file() = joinpath(REPO_ROOT, "examples", "queries", "commute_queries.jl")
default_trace_dir() = joinpath(@__DIR__, "trace", "reviewer_demo")

function parse_cli(args::Vector{String})
    cfg = (
        diagram_file=default_diagram_file(),
        query_file=default_query_file(),
        trace_dir=default_trace_dir(),
        write_trace=true,
        step4_verbose=false,
    )

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--diagram"
            i += 1
            i <= length(args) || error("Missing value after --diagram")
            cfg = merge(cfg, (diagram_file=normpath(abspath(args[i])),))
        elseif a == "--queries"
            i += 1
            i <= length(args) || error("Missing value after --queries")
            cfg = merge(cfg, (query_file=normpath(abspath(args[i])),))
        elseif a == "--trace-dir"
            i += 1
            i <= length(args) || error("Missing value after --trace-dir")
            cfg = merge(cfg, (trace_dir=normpath(abspath(args[i])),))
        elseif a == "--no-trace"
            cfg = merge(cfg, (write_trace=false,))
        elseif a == "--step4-verbose"
            cfg = merge(cfg, (step4_verbose=true,))
        elseif a == "--help" || a == "-h"
            println("Usage:")
            println("  julia --project=. src/run_demo.jl [options]")
            println()
            println("Options:")
            println("  --diagram <path>       Diagram/model example file")
            println("                         (StringDiagram default: examples/string_diagrams/commute_scm.jl)")
            println("                         (ADMG examples: examples/admg_models/*.jl)")
            println("  --queries <path>       Query example file (default: examples/queries/commute_queries.jl)")
            println("  --trace-dir <path>     Trace output directory (default: src/trace/reviewer_demo)")
            println("  --no-trace             Disable trace export")
            println("  --step4-verbose        Enable verbose Step4 logs")
            println("  -h, --help             Show this help")
            exit(0)
        else
            error("Unknown argument: $a")
        end
        i += 1
    end

    return cfg
end

has_key(nt::NamedTuple, s::Symbol) = s in keys(nt)
get_opt(nt::NamedTuple, s::Symbol, default) = has_key(nt, s) ? getproperty(nt, s) : default

function load_example(path::String, label::String)
    isfile(path) || error("$label file not found: $path")
    cfg = include(path)
    cfg isa NamedTuple || error("$label file must return a NamedTuple. got: $(typeof(cfg))")
    return cfg
end

function build_rule_config(query_cfg::NamedTuple)
    raw = get_opt(query_cfg, :rules, (enabled=false, directed_edges=Tuple{String,String}[],))
    return raw isa Step5RuleConfig ? raw : Step5RuleConfig(; raw...)
end

function build_display_config(query_cfg::NamedTuple)
    raw = get_opt(query_cfg, :display, NamedTuple())
    return raw isa Step5DisplayConfig ? raw : Step5DisplayConfig(; raw...)
end

function build_data_config(query_cfg::NamedTuple)
    raw = get_opt(query_cfg, :data, NamedTuple())
    return raw isa Step5DataConfig ? raw : Step5DataConfig(; raw...)
end

function print_summary(res)
    println("identifiable = ", res.identifiable)
    println("formula      = ", res.data_tex)
    println("failure_stage= ", res.failure_stage)
    println("error        = ", res.error)
    println("timings_ms   = ", res.timings_ms)
    if !isempty(res.trace_paths)
        println("trace files:")
        for (k, v) in sort(collect(res.trace_paths); by=first)
            println("  ", k, " -> ", v)
        end
    end
end

function main(args::Vector{String})
    cli = parse_cli(args)
    diagram_cfg = load_example(cli.diagram_file, "Diagram")
    query_cfg = load_example(cli.query_file, "Query")

    has_key(diagram_cfg, :input) || error("Diagram file must provide `input`.")
    has_key(query_cfg, :queries) || error("Query file must provide `queries`.")

    display_syms = get_opt(query_cfg, :display_syms, get_opt(diagram_cfg, :display_syms, Symbol[]))
    output_vars = get_opt(query_cfg, :output_vars, get_opt(diagram_cfg, :output_vars, String[]))
    trace_dir = cli.write_trace ? cli.trace_dir : nothing

    diagram_name = get_opt(diagram_cfg, :name, basename(cli.diagram_file))
    query_name = get_opt(query_cfg, :name, basename(cli.query_file))

    println("diagram_file = ", cli.diagram_file)
    println("query_file   = ", cli.query_file)
    println("diagram_name = ", diagram_name)
    println("query_name   = ", query_name)
    println("trace_dir    = ", trace_dir === nothing ? "(disabled)" : trace_dir)
    println()

    res = identify_counterfactual(
        diagram_cfg.input,
        query_cfg.queries;
        display_syms=display_syms,
        output_vars=output_vars,
        step4_verbose=cli.step4_verbose,
        rules=build_rule_config(query_cfg),
        display=build_display_config(query_cfg),
        data=build_data_config(query_cfg),
        trace_dir=trace_dir,
        trace_prefix=string(diagram_name, "__", query_name),
    )

    print_summary(res)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
