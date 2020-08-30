cd(@__DIR__)
using Pkg; Pkg.activate(homedir()*"/Documents/work/rai/raicode-clean")
using DelveSDK

include("gamedisplay.jl")

const conn = LocalConnection(;dbname=:pacman)
win,ch = init_win()

function init_game(conn)
    create_database(conn, overwrite=true)

    install_source(conn, path="game.delve")

    # Initialize the level via these write transaciton queries. Characters must come first.
    query(conn, read("level1_characters.delvequery", String), readonly=false)
    query(conn, read("level1_environment.delvequery", String), readonly=false)

    # NOTE: This must come _after_ the level is loaded for now, due to bug.
    install_source(conn, path="updates.delve")

    @info "--initialized--"
    draw_frame(conn)
end
function draw_frame(conn)
    ((w,),), ((h,),) = query(conn, out=(:grid_w, :grid_h))
    global w,h = w,h
    #global g = query(conn, "def insert[:tick]=true", out=:display_grid_topdown, readonly=false)
    global g = query(conn, out=:display_grid_topdown)

    global ghost_colors = Dict(query(conn, out=:ghost_color))
    display_grid!(win, w,h, ghost_colors, g)
end
function update!(conn)
    query(conn, "def insert[:tick]=true", readonly=false)
end

const kUP=1; const kDOWN=2; const kLEFT=3; const kRIGHT=4
function handle_input!(conn, arrow_key)
    @info "input: $arrow_key"
    q = """
        def delete[:pacman_facing_x] = pacman_facing_x
        def delete[:pacman_facing_y] = pacman_facing_y
    """

    @info if arrow_key == kUP
        query(conn, q * """
            def insert[:pacman_facing_x] = 0.0
            def insert[:pacman_facing_y] = 1.0
        """, readonly=false, out=[:pacman_facing_x,:pacman_facing_y])
    elseif arrow_key == kDOWN
        query(conn, q * """
            def insert[:pacman_facing_x] = 0.0
            def insert[:pacman_facing_y] = -1.0
        """, readonly=false, out=[:pacman_facing_x,:pacman_facing_y])
    elseif arrow_key == kLEFT
        query(conn, q * """
            def insert[:pacman_facing_x] = -1.0
            def insert[:pacman_facing_y] = 0.0
        """, readonly=false, out=[:pacman_facing_x,:pacman_facing_y])
    elseif arrow_key == kRIGHT
        query(conn, q * """
            def insert[:pacman_facing_x] = 1.0
            def insert[:pacman_facing_y] = 0.0
        """, readonly=false, out=[:pacman_facing_x,:pacman_facing_y])
    else
        @error "UNEXPECTED arrow_key: $arrow_key"
    end
end
function start_key_listener()
    global kt = @async begin
        while true
            k = take!(ch)
            handle_input!(conn, k)
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
