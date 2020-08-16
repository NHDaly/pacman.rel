function print_grid(g)
    Y = g[1][1]
    for (y,x,c) in g
        if y != Y
            println("")
            Y=y
        end
        print(c,' ')
    end
end
