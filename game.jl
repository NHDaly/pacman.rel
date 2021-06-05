########################################################################
# Pacman.delve
#
# This file is the main driver for the PacMan game implemented in Delve!
#
# To run, simply set DELVE_PATH to a julia project that provides DelveSDK,
# and include this file, then run frames via `runloop(conn, num_frames)`:
# ```
# $ DELVE_PATH=../raicode julia -i game.jl
# $ julia> runloop(conn, 30)  # run 30 frames of the game
# ```
#
########################################################################


cd(@__DIR__)

# By default, use my (NHD) personal path to the DelveSDK packages:
const DELVE_PATH = get(ENV, "DELVE_PATH", homedir()*"/work/raicode-clean")

using Pkg; Pkg.activate(DELVE_PATH)
using DelveSDK

include("gamedisplay.jl")

conn = LocalConnection(;dbname=:pacman)

function init_game(conn)
    global win,ch = init_win()
    connect_window_listener()
    start_key_listener()

    create_database(conn, overwrite=true)

    install_source(conn, path="game.delve")

    # Initialize the level via these write transaciton queries. Characters must come first.
    query(conn, read("level1_characters.delvequery", String), readonly=false)
    query(conn, read("level1_environment.delvequery", String), readonly=false)

    # NOTE: This must come _after_ the level is loaded for now, due to bug.
    install_source(conn, path="updates.delve")
    install_source(conn, path="ghosts.delve")

    @info "--initialized--"
    draw_frame(conn)
end
function draw_frame(conn)
    global ((w,),), ((h,),), g, ((score,),), ((lives,),) =
        query(conn, out=(:grid_w, :grid_h, :display_grid_topdown, :score, :lives))

    global ghost_colors = Dict(query(conn, out=:ghost_color_by_id))
    display_grid!(win, w,h, ghost_colors, g, score, lives)
end
function update!(conn)
    query(conn, "def insert[:tick]=true", readonly=false)
end

const kUP=1; const kDOWN=2; const kLEFT=3; const kRIGHT=4
function handle_input!(conn, arrow_key)
    @info "input: $arrow_key"
    q = """
        def delete[:pacman_facing] = pacman_facing
    """

    if arrow_key == kUP
        query(conn, q * """
            def insert[:pacman_facing][:x] = 0.0
            def insert[:pacman_facing][:y] = 1.0
        """, readonly=false)
    elseif arrow_key == kDOWN
        query(conn, q * """
            def insert[:pacman_facing][:x] = 0.0
            def insert[:pacman_facing][:y] = -1.0
        """, readonly=false)
    elseif arrow_key == kLEFT
        query(conn, q * """
            def insert[:pacman_facing][:x] = -1.0
            def insert[:pacman_facing][:y] = 0.0
        """, readonly=false)
    elseif arrow_key == kRIGHT
        query(conn, q * """
            def insert[:pacman_facing][:x] = 1.0
            def insert[:pacman_facing][:y] = 0.0
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
            Threads.@spawn handle_input!(conn, k)
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

init_game(conn)


function runloop(conn, maxframes::Union{Int,Nothing} = nothing)
    i = 0
    while true
        i += 1
        if maxframes !== nothing && i > maxframes
            break
        end
        update!(conn); draw_frame(conn);
    end
end