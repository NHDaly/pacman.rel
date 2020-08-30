cd(@__DIR__)
using Pkg; Pkg.activate(homedir()*"/Documents/work/rai/raicode-clean")
using DelveSDK

include("gamedisplay.jl")

const conn = LocalConnection(;dbname=:pacman)
win = init_win()

function init_game(conn)
    create_database(conn, overwrite=true)

    install_source(conn, path="game.delve")

    # Initialize the level via these write transaciton queries. Characters must come first.
    query(conn, read("level1_characters.delvequery", String), readonly=false)
    query(conn, read("level1_environment.delvequery", String), readonly=false)

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
init_game(conn)
