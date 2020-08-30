cd(@__DIR__)
using Pkg; Pkg.activate(homedir()*"/Documents/work/rai/raicode-clean")
using DelveSDK

include("gamedisplay.jl")

const conn = LocalConnection(;dbname=:pacman)
win = init_win()


function init_game(conn)
    create_database(conn, overwrite=true)

    # First, load the level CSV
    #query(conn, """ def walls_csv = load_csv["level1_walls.csv"] """, readonly=false)
    #query(conn, """ def dots_csv = load_csv["level1_dots.csv"] """, readonly=false)
    #load_csv(conn, :walls_csv, path=pwd()*"/level1_walls.csv",
    #    schema=CSVFileSchema([Int,Int]))
    #load_csv(conn, :superdots_csv, path=pwd()*"/level1_superdots.csv",
    #    schema=CSVFileSchema([Int,Int]))
    install_source(conn, path="level1_data.delve")

    install_source(conn, path="game.delve")
    query(conn, "def insert[:init] = true", readonly=false)

    ((w,),), ((h,),) = query(conn, out=(:grid_w, :grid_h))
    global w,h = w,h
    global g = query(conn, "def insert[:tick]=true", out=:display_grid_topdown, readonly=false)

    global ghost_colors = Dict(query(conn, out=:ghost_color))
    display_grid!(win, w,h, ghost_colors, g)
end
init_game(conn)
