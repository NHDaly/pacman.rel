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
engine = get(ENV, "RAI_ENGINGE", "nhd-S-2")
config = (ctx, dbname, engine)

function install_model(config...; path)
    load_model(config..., Dict(path => read(path, String)))
end

function init_game(config...)
    global win,ch = init_win()
    connect_window_listener()
    start_key_listener()

    create_database(config..., overwrite=true)
    @info "created database"

    exec(config..., """
        def insert:rel:catalog:model["dummy"] = \"""
        // HACK: to work around the bug in the Transactions Service sending empty results
        // always install an output so there's never empty results.
        def output:__dummy__ = 1
        \"""
        """, readonly=false)

    load_model(config..., Dict("game.rel" => read("game.rel", String)))

    # Initialize the level via these write transaciton queries. Characters must come first.
    exec(config..., read("level1_characters.relquery", String), readonly=false)
    exec(config..., read("level1_environment.relquery", String), readonly=false)

    # NOTE: This must come _after_ the level is loaded for now, due to bug.
    install_model(config..., path="updates.rel")
    install_model(config..., path="ghosts.rel")

    @info "--initialized--"
    draw_frame(config...)
end
function draw_frame(config...)
    global vs = exec(config..., """:grid_w,grid_w; :grid_h,grid_h;
         :display_grid_topdown,display_grid_topdown; :score,score; :lives,lives;
         :dying_anim_frame,dying_anim_frame""")

    @show [r[1] for r in vs["results"]]

    global ((w,),), ((h,),), g, ((score,),), ((lives,),), ((dying_anim_frame,),) =
        filter(vs, ":grid_w")[1][2],
        filter(vs, ":grid_h")[1][2],
        filter(vs, ":display_grid_topdown")[1][2],
        filter(vs, ":score")[1][2],
        filter(vs, ":lives")[1][2],
        filter(vs, ":dying_anim_frame")[1][2]

    global ghost_colors = Dict(exec(config..., "ghost_color_by_id"))
    display_grid!(win, w,h, ghost_colors, g, score, lives, dying_anim_frame)
end
function filter(response, key)
    return [r
            for (metadata,r)
            in zip(response["metadata"], response["results"])
            if metadata.types[2] == key
           ]
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
