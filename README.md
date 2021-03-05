# pacman.delve

An implementation of PacMan, written in Delve

To run:

```julia
julia> include("game.jl")

julia> runloop(conn, 20)
```

## Organization

The delve logic installed in the database for the game is all defined in the `.delve` files; as of time of writing, those are:
- game.delve
- updates.delve
- ghosts.delve

The database state is initialized by issuing a _write_ transaction with the `.delvequery` files, which unfortunately currently must be run in a certain order. See `init_game(conn)` in game.jl for that.

The game is driven by the julia driver script: `game.jl`, and the board is rendered by `gamedisplay.jl` as a javascript `<canvas>` via Electron.jl.
