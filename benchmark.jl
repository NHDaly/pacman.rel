module PacmanBenchmark

using RAI
using JSON3
using Statistics: mean

ctx = RAI.Context(RAI.load_config())
dbname = "nhd-pacman-benchmark"
engine = get(ENV, "RAI_ENGINE", "nhd-s")
config = (ctx, dbname, engine)

"""
    run_and_write_benchmark(config[, num_frames];
                            result_file = "pacman_benchmark_results.json")

Run the pacman benchmark for `num_frames` frames, and write the result as a JSON file to
the file path specified by `result_file`.
"""
function run_and_write_benchmark(config, num_ticks = 30;
                                 result_file = "pacman_benchmark_results.json")
    out = run_benchmark(config, num_ticks)
    write_benchmark_results(out)
end

function write_benchmark_results(results,
                                 result_file = "pacman_benchmark_results.json")
    JSON3.write(result_file, results)

    @info "Results written to '$result_file'."
end

#------------------------------------------------------------------------------------------
# These functions are copied/modified from pacman.rel/src/game.jl

function install_model(config...; path)
    load_models(config..., Dict(path => read(path, String)))
end

function init_game(config)
    create_database(config..., overwrite=true)

    @info """
    ---------------- Initializing Database ---------------------------
    ** NOTE: **
    Installing definitions is about to emit a bunch of `undefined` definition warnings.
    These are actually expected, and are part of the user program (pacman)'s initialization,
    because some of the data isn't loaded yet, so some of the installed relation definitions
    will depend on relations that don't exist yet. Those are then resolved in the subsequent
    transactions, which load the data for the game.

    Please ignore the `undefined` warnings, below.
    -----------------------------------------------------------------
    """

    cd(@__DIR__) do
        install_model(config..., path="game.rel")

        # Initialize the level via these write transaciton queries. Characters must come first.
        exec(config..., read("level1_characters.relquery", String), readonly=false)
        exec(config..., read("level1_environment.relquery", String), readonly=false)

        # NOTE: This must come _after_ the level is loaded for now, due to bug.
        install_model(config..., path="updates.rel")
        install_model(config..., path="ghosts.rel")
    end
end

function filter(response, key)
    return [r[2]
            for (metadata,r)
            in zip(response.metadata.relations, response.results)
            if _relname(metadata.relation_id) == key
           ]
end
function _relname(relation_id)
    if !(length(relation_id.arguments) >= 2 && relation_id.arguments[2].tag == RAI.relationalai.protocol.Kind.CONSTANT_TYPE)
        return nothing
    end
    top_level_name = String(copy(relation_id.arguments[1].constant_type.value.arguments[1].value.value))
    top_level_name == "output" || return nothing
    relname = String(copy(relation_id.arguments[2].constant_type.value.arguments[1].value.value))
    return relname
end
function update!(config)
    exec(config..., "def insert:tick = true", readonly=false)
end
function render(config)
    global outs = exec(config..., """:grid_w,grid_w; :grid_h,grid_h;
         :display_grid_topdown,display_grid_topdown; :score,score; :lives,lives;
         :dying_anim_frame,dying_anim_frame""")
    print_frame(outs)
end

function print_frame(vs)
    global ((w,),) = filter(vs, "grid_w")[1]
    global ((h,),) = filter(vs, "grid_h")[1]
    global g = filter(vs, "display_grid_topdown")[1]
    global ((score,),) = filter(vs, "score")[1]
    global ((lives,),) = filter(vs, "lives")[1]
    dying_anim_frame = 0
    # global ((dying_anim_frame,),) = filter(vs, "dying_anim_frame")[1]
    g = zip(g...)
    grid_dict = Dict((x, y) => Char(c) for (x, y, c) in g)
    for y in 1:h
        for x in 1:w
            v = get(grid_dict, (x,y), ' ')
            v = v === 'D' ? ' ' : v  # don't print Decision points, they're distracting
            print(v)
        end
        println()
    end
    println("Score: $score    Lives: $lives     Alive: $dying_anim_frame")
end

#------------------------------------------------------------------------------------------
# Benchmarking utilities:

create_record(timed) =
    (time_s = timed.time, bytes = timed.bytes, gctime_s = timed.gctime, allocs = Base.gc_alloc_count(timed.gcstats),)
agg_records(records, op) =
    (time_s = op(getindex.(records, :time_s)),
     bytes = op(getindex.(records, :bytes)),
     gctime_s = op(getindex.(records, :bytes)),
     allocs = op(getindex.(records, :allocs)),
     )

function run_benchmark(config = config, num_ticks=30)
    init_record = create_record(@timed init_game(config))

    VT = Vector{typeof(init_record)}
    update_times, render_times, frame_times = VT(), VT(), VT()

    for i in 1:num_ticks
        @info "frame $i:"
        f = @timed begin
            u = @timed update!(config)
            r = @timed render(config)
        end
        push!(update_times, create_record(u))
        push!(render_times, create_record(r))
        push!(frame_times, create_record(f))
    end

    out = Dict()

    out["initialize"] = init_record

    out["num_frames"] = num_ticks
    out["update_total"] = agg_records(update_times, sum)
    out["render_total"] = agg_records(render_times, sum)
    out["frame_total"] = agg_records(frame_times, sum)

    out["update_mean"] = agg_records(update_times, mean)
    out["render_mean"] = agg_records(render_times, mean)
    out["frame_mean"] = agg_records(frame_times, mean)

    out["update_min"] = agg_records(update_times, minimum)
    out["render_min"] = agg_records(render_times, minimum)
    out["frame_min"] = agg_records(frame_times, minimum)

    out["update_max"] = agg_records(update_times, maximum)
    out["render_max"] = agg_records(render_times, maximum)
    out["frame_max"] = agg_records(frame_times, maximum)

    return out
end

end  # module PacmanBenchmark
