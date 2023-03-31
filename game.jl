########################################################################
# Pacman.rel
#
# This file is the main driver for the PacMan game implemented in Delve!
#
# To run, simply set DELVE_PATH to a julia project that provides RelationalAI,
# and include this file, then run frames via `runloop(config..., num_frames)`:
# ```
# $ DELVE_PATH=../raicode julia -i game.jl
# $ julia> runloop(config..., 30)  # run 30 frames of the game
# ```
#
########################################################################


cd(@__DIR__)

include("gamedisplay.jl")

using RAI

ctx = RAI.Context(RAI.load_config())
dbname = "nhd-pacman"
engine = get(ENV, "RAI_ENGINE", "nhd-s")
config = (ctx, dbname, engine)

function install_model(config...; path)
    load_models(config..., Dict(path => read(path, String)))
end

function init_game(config...)
    global win,ch = init_win()
    connect_window_listener()
    start_key_listener()

    try
        delete_database(config...)
    catch
    end
    create_database(config...)
    @info "created database"

    # exec(config..., """
    #     def insert:rel:catalog:model["dummy"] = \"""
    #     // HACK: to work around the bug in the Transactions Service sending empty results
    #     // always install an output so there's never empty results.
    #     def output:__dummy__ = 1
    #     \"""
    #     """, readonly=false)

    load_models(config..., Dict(
        path => read(path, String)
        for path in ("game.rel", "ghosts.rel", "updates.rel")
    ))
    install_model(config..., path="game.rel")

    # Initialize the level via these write transaciton queries. Characters must come first.
    exec(config..., read("level1_characters.relquery", String), readonly=false)
    exec(config..., read("level1_environment.relquery", String), readonly=false)

    # NOTE: This must come _after_ the level is loaded for now, due to bug.
    install_model(config..., path="updates.rel")
    install_model(config..., path="ghosts.rel")

    @info "--initialized--"
    draw_frame(config...)
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
function draw_frame(config...)
    global vs = exec(config..., """:grid_w,grid_w; :grid_h,grid_h;
         :display_grid_topdown,display_grid_topdown; :score,score; :lives,lives;
         :dying_anim_frame,dying_anim_frame""")

    global ((w,),) = filter(vs, "grid_w")[1]
    global ((h,),) = filter(vs, "grid_h")[1]
    global g = filter(vs, "display_grid_topdown")[1]
    global ((score,),) = filter(vs, "score")[1]
    global ((lives,),) = filter(vs, "lives")[1]
    #global ((dying_anim_frame,),) = filter(vs, ":dying_anim_frame")[1]
    global dying_anim_frame = 0

    global ghost_colors = Dict(zip(filter(
        exec(config..., ":ghost_colors, ghost_color_by_id"), "ghost_colors")[1]...))

    display_grid!(win, w,h, ghost_colors, g, score, lives, dying_anim_frame)
end
function update!(config...)
    exec(config..., "def insert:tick = true", readonly=false)
end

const kUP=1; const kDOWN=2; const kLEFT=3; const kRIGHT=4
function handle_input!(config, arrow_key)
    @info "input: $arrow_key"
    q = """
        def delete:pacman_facing = pacman_facing
    """

    if arrow_key == kUP
        exec(config..., q * """
            def insert:pacman_facing:x = 0.0
            def insert:pacman_facing:y = 1.0
        """, readonly=false)
    elseif arrow_key == kDOWN
        exec(config..., q * """
            def insert:pacman_facing:x = 0.0
            def insert:pacman_facing:y = -1.0
        """, readonly=false)
    elseif arrow_key == kLEFT
        exec(config..., q * """
            def insert:pacman_facing:x = -1.0
            def insert:pacman_facing:y = 0.0
        """, readonly=false)
    elseif arrow_key == kRIGHT
        exec(config..., q * """
            def insert:pacman_facing:x = 1.0
            def insert:pacman_facing:y = 0.0
        """, readonly=false)
    else
        @error "UNEXPECTED arrow_key: $arrow_key"
    end
end
function start_key_listener()
    global kt = @async begin
        while true
            k = take!(ch)
            # Multiple writes may simply fail, but that's fine! :)
            Threads.@spawn handle_input!(config, k)
        end
    end
end


function connect_window_listener()
    result = run(win, """
        function keyDownHandler(event) {
            console.log(event);
            let UP = 1
            let DOWN = 2
            let LEFT = 3
            let RIGHT = 4
            if(event.keyCode == 39) {
                arrow_key_span.innerText = '➡️️'
                sendMessageToJulia(RIGHT);
            }
            else if(event.keyCode == 37) {
                arrow_key_span.innerText = '⬅️️'
                sendMessageToJulia(LEFT);
            }
            if(event.keyCode == 40) {
                arrow_key_span.innerText = '⬇️'
                sendMessageToJulia(DOWN);
            }
            else if(event.keyCode == 38) {
                arrow_key_span.innerText = '⬆️'
                sendMessageToJulia(UP);
            }
        }
        document.addEventListener('keydown', keyDownHandler, false);
        """)
end

init_game(config...)


function runloop(config, maxframes::Union{Int,Nothing} = nothing)
    i = 0
    while true
        i += 1
        if maxframes !== nothing && i > maxframes
            break
        end
        update!(config...); draw_frame(config...);
    end
end
