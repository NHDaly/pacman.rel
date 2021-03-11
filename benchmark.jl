module PacmanBenchmark

using DelveSDK
using JSON
using Statistics: mean

conn = LocalConnection(;dbname=:pacman)

"""
    run_and_write_benchmark(conn[, num_frames];
                            result_file = "pacman_benchmark_results.json")

Run the pacman benchmark for `num_frames` frames, and write the result as a JSON file to
the file path specified by `result_file`.
"""
function run_and_write_benchmark(conn, num_ticks = 30;
                                 result_file = "pacman_benchmark_results.json")
    out = run_benchmark(conn, num_ticks)

    write(result_file, JSON.json(out))

    @info "Results written to '$result_file'."
end

#------------------------------------------------------------------------------------------
# These functions are copied/modified from pacman.delve/src/game.jl

function init_game(conn)
    create_database(conn, overwrite=true)

    install_source(conn, path="game.delve")

    # Initialize the level via these write transaciton queries. Characters must come first.
    query(conn, read("level1_characters.delvequery", String), readonly=false)
    query(conn, read("level1_environment.delvequery", String), readonly=false)

    # NOTE: This must come _after_ the level is loaded for now, due to bug.
    install_source(conn, path="updates.delve")
    install_source(conn, path="ghosts.delve")
end

function update!(conn)
    query(conn, "def insert[:tick]=true", readonly=false)
end
function render(conn)
    query(conn, out=(:grid_w, :grid_h, :display_grid_topdown, :score, :lives, :ghost_color_by_id))
end

#------------------------------------------------------------------------------------------
# Benchmarking utilities:

create_record(timed) =
    (time_s = timed.time, bytes = timed.bytes, gctime_s = timed.gctime)
agg_records(records, op) =
    (time_s = op(getindex.(records, :time_s)),
     bytes = op(getindex.(records, :bytes)),
     gctime_s = op(getindex.(records, :bytes)))

function run_benchmark(conn, num_ticks=30)
    init_record = create_record(@timed init_game(conn))

    VT = Vector{typeof(init_record)}
    update_times, render_times, frame_times = VT(), VT(), VT()

    for i in 1:num_ticks
        @info "frame $i:"
        f = @timed begin
            u = @timed update!(conn)
            r = @timed render(conn)
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
