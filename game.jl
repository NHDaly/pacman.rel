cd(@__DIR__)
using Pkg; Pkg.activate(homedir()*"/work/raicode-clean")
using DelveSDK

include("gamedisplay.jl")

conn = LocalConnection(;dbname=:pacman, port=1121)
win,ch = init_win()

function init_game(conn)
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
start_key_listener()



result = run(win, """
    function keyDownHandler(event) {
        console.log(event);
        let UP = 1
        let DOWN = 2
        let LEFT = 3
        let RIGHT = 4
        if(event.keyCode == 39) {
            sendMessageToJulia(RIGHT);
        }
        else if(event.keyCode == 37) {
            sendMessageToJulia(LEFT);
        }
        if(event.keyCode == 40) {
            sendMessageToJulia(DOWN);
        }
        else if(event.keyCode == 38) {
            sendMessageToJulia(UP);
        }
    }
    document.addEventListener('keydown', keyDownHandler, false);
    """)


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