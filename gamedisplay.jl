using Pkg
Pkg.activate(".")
using Electron


function init_win()
    win = Window(URI("file://main.html"))
    load(win, """
        <canvas id="canvas"></canvas>
        <style>
            body {
            background-color: #222;
            overflow: hidden;
            }
            canvas {
            background-color: #000;
            display: block;
            position:absolute;
            margin: auto;
            top:0;bottom:0;left:0;right:0
            }
        </style>
        <script>
            const canvas = document.getElementById("canvas");
            const ctx = canvas.getContext("2d");
            let cw = (canvas.width = 400),
            cx = cw / 2;
            let ch = (canvas.height = 600),
            cy = ch / 2;
       </script>
        """)
    return win
end

function display_grid!(win, g_width, g_height, ghost_colors, g)

    # food radius
    elements_str = join([
        """
        {
        // Not sure why, but need to subtract 0.5 from x for it to line up nicely..
        let x = $(x-0.5) * cellw;
        let y = $(y) * cellw;
        ctx.beginPath();
        """ *
        if c == '.'
            """
            ctx.arc(x, y, pellet_radius, 0, 2 * Math.PI);
            ctx.fillStyle = "lightyellow";
            ctx.fill();
            """
        elseif c == '*'
            """
            ctx.arc(x, y, superdot_radius, 0, 2 * Math.PI);
            ctx.fillStyle = "lightyellow";
            ctx.fill();
            """
        elseif c == 'W'
            """
            ctx.fillStyle = "white";
            ctx.fillRect(x-cellw/2, y-cellw/2, cellw, cellw);
            """
        elseif c == 'P'
            """
            ctx.arc(x, y, pacman_radius, Math.PI / 4, -Math.PI / 4);
            ctx.lineTo(x, y);
            ctx.fillStyle = "gold";
            ctx.fill();
            """
        elseif c ∈ ('1','2','3','4')
            color = ghost_colors[parse(Int, string(c))]
            """
            x -= ghost_radius/2;
            y -= ghost_radius/2;
            let r = 28 / ghost_radius;
            ctx.fillStyle = $(repr(color));
            ctx.beginPath();
            ctx.moveTo(x - r/2, y - r/2);
            ctx.lineTo(x + 0, y + -14/r);
            ctx.bezierCurveTo(x + 0, y - 22/r, x + 6/r, y - 28/r, x + 14/r, y - 28/r);
            ctx.bezierCurveTo(x + 22, y - 28/r, x + 28/r, y - 22/r, x + 28/r, y - 14/r);
            ctx.lineTo(x + 28, y + 0);
            ctx.lineTo(x + 23.333, y + -5.333/r);
            ctx.lineTo(x + 18.666, y + 0/r);
            ctx.lineTo(x + 14, y + -5.333/r);
            ctx.lineTo(x + 9.333, y + 0/r);
            ctx.lineTo(x + 4.666, y + -5.333/r);
            ctx.lineTo(x + 0, y + 0/r);
            ctx.fill();
            """
        end *
        """
        }
        """

        for (x,y,c) in g
    ], "\n")

    result = run(win, """
        {
            // Start by clearing out the previous frame.
            ctx.fillStyle = 'rgb(0, 0, 0)';
            ctx.fillRect(0, 0, cw, ch);

            let cellw = cw / $g_width;

            pellet_radius = cellw * 0.1;
            superdot_radius = cellw * 0.5;
            pacman_radius = cellw * 0.5;
            ghost_radius = cellw * 2.0;


            $elements_str
        }
        """)

end
