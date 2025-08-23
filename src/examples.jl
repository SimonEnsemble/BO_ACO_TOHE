function darpa_urban_environment(nb_robots::Int; seed::Int=97330)
    Random.seed!(seed)
	g = MetaDiGraph(SimpleDiGraph(73))
	
	#=
	edge list (see drawing)
	m = main atrium traversal
	h = hallway traversal
	f = floor traversal
	o = official obstacle in map
	=#
	edge_list = [
		#=
		zone A
		=#
		# main
		(1, 3, :m),
		(3, 4, :m),
		(3, 8, :m),
		# hallway
		(8, 15, :h),
		(8, 16, :h),
		(8, 14, :h),
		(8, 42, :h),
		(1, 2, :h),
		(3, 13, :h),
		#=
		zone A <-> B
		=#
		(3, 4, :m),
		#=
		zone A <-> C
		=#
		(8, 9, :m),
		#=
		floor 1 <--> floor 2
		         =
		zone A <-> zone E
		=#
		(2, 46, :f),
		#=
		zone B
		=#
		# main
		(4, 29, :m),
		(4, 6, :o),
		(4, 5, :m),
		(4, 35, :m),
		(5, 36, :o),
		(7, 34, :m),
		# hallway
		(36, 41, :h),
		(36, 39, :h),
		(39, 40, :h),
		(39, 38, :h),
		(39, 37, :h),
		(6, 30, :h),
		(6, 31, :h),
		(6, 7, :h),
		(7, 32, :h),
		(7, 33, :h),
		#=
		zone C
		=#
		# main
		(9, 10, :m),
		# hallway
		(9, 17, :h),
		(9, 18, :h),
		(10, 19, :h),
		(10, 20, :h),
		(10, 21, :h),
		#=
		zone C <-> D
		=#
		(10, 11, :m),
		#=
		zone D
		=#
		# main
		(11, 28, :m),
		(11, 27, :m),
		(27, 45, :m),
		(12, 24, :m),
		# hallway
		(11, 12, :h),
		(24, 25, :h),
		(25, 26, :h),
		(12, 23, :h),
		(12, 22, :h),
		(23, 44, :h),
		#=
		zone E
		=#
		# main
		(46, 47, :m),
		(47, 51, :m),
		(51, 56, :m),
		# hallway
		(51, 52, :h),
		(51, 53, :h),
		(51, 57, :h),
		(57, 55, :h),
		(55, 54, :h),
		
		(51, 43, :h),
		(43, 58, :h),
		
		(51, 73, :h),
		(73, 59, :h),

		(51, 72, :h),
		(72, 60, :h),
		#=
		zone E <-> zone F
		=#
		(51, 61, :m),
		#=
		zone E <-> zone G
		=#
		(47, 48, :m),
		#=
		zone G
		=#
		(48, 50, :h),
		(48, 42, :h),
		(48, 49, :h),
		#=
		zone F
		=#
		(61, 62, :m),
		(62, 63, :m),
		
		(62, 69, :h),
		(69, 65, :h),

		(62, 68, :h),
		(68, 64, :h),

		(61, 70, :h),
		(70, 66, :h),
		
		(61, 71, :h),
		(71, 67, :h)
	]

	# g = gas
	# c = cell phone
	# b = backpack
	# v = vent
	# s = survivor
	# omit if nothing
	artifact_type = Dict(
		# zone A
		13=>"g",
		15=>"b",
		# zone B
		29=>"s",
		30=>"b",
		31=>"c",
		32=>"c",
		34=>"b",
		33=>"v",
		40=>"g",
		37=>"c",
		38=>"c",
		# zone C
		9=>"b",
		17=>"g",
		18=>"s",
		19=>"v",
		20=>"b",
		21=>"g",
		# zone D
		11=>"c",
		28=>"s",
		45=>"v",
		12=>"s",
		24=>"b",
		25=>"b",
		22=>"c",
		44=>"v",
		# zone E
		46=>"b",
		56=>"c",
		58=>"g",
		55=>"s",
		# zone G
		50=>"v",
		49=>"s",
		# zone F
		66=>"g",
		62=>"c",
		63=>"b"
	)
	
    # made up but plausible.
	ωs = Dict(
		:o => 0.75,
		:m => 0.98,
		:h => 0.95,
		:f => 0.8
	)
	
	for (i, j, t) in edge_list
		add_edge!(g, i, j)
		add_edge!(g, j, i)
		set_prop!(g, i, j, :ω, ωs[t])
		set_prop!(g, j, i, :ω, ωs[t])
	end
	    
    # totally made up.
	artifact_reward = Dict(
		"s" => 0.50,
		"c" => 0.30,
		"b" => 0.20,
		"g" => 0.15,
		"v" => 0.12
	)
	for v = 1:nv(g)
		r = (v in keys(artifact_type)) ? artifact_reward[artifact_type[v]] : 0.0
		set_prop!(g, v, :r, r)
	end
	set_prop!(g, 1, :r, 0.0)
	return TOP(
       nv(g),
       g,
       nb_robots
     )
end

function art_museum_layout(scale::Float64)
	# read in node locations from plot digitizer of art museum map
	raw_node_locs = split.(readlines("art_museum_node_locs.csv"), ",")
	xs = [parse(Float64, rnl[1]) for rnl in raw_node_locs]
	ys = -1 * [parse(Float64, rnl[2]) for rnl in raw_node_locs] # reflect

	# standardize
	r = maximum(xs) - minimum(xs) # avoid stretching one more than another
	xs = (xs .- minimum(xs)) / r
	ys = (ys .- minimum(ys)) / r

	# manual adjustments
	# node 4 bring it down
	ys[4] -= 0.05

	# move floor 2 nodes
	f2_nodes = [21, 22, 23, 27, 24, 25, 26]
	# xs[f2_nodes]
	xs[f2_nodes] .-= 0.05
	ys[f2_nodes] .-= 0.8

	# scale
	xs *= scale
	ys *= scale

	# wut the graph makie wants
	spatial_layout = Point2{Float64}[]
	for (x, y) in zip(xs,  ys)
		pos = Point2{Float64}(x, y)
		push!(spatial_layout, pos)
	end
	return spatial_layout
end

"""
the San Diego art museum
"""
function art_museum(nb_robots::Int)
	g = MetaDiGraph(SimpleDiGraph(27))
	edge_list = [
        # floor 1
        # in main
        (1, 2, "m"),
        (2, 3, "m"),
        (2, 8, "m"),
        # in/out of main
        (2, 9, "iom"),
        (2, 4, "iom"),
        (8, 10, "iom"),
        (8, 6, "iom"),
        # main to floor 2 (floor transition)
        (2, 21, "ft"),
        # left
        (9, 10, "l"),
        (9, 16, "l"),
        (10, 11, "l"),
        (11, 12, "l"),
        (11, 14, "l"),
        (16, 15, "l"),
        (14, 15, "l"),
        (12, 13, "l"),
        (14, 13, "l"),
        (12, 18, "l"),
        (17, 18, "l"),
        (17, 14, "l"),
        (20, 14, "l"),
        (14, 19, "l"),
        (20, 19, "l"),
        # right
        (4, 5, "r"),
        (5, 3, "r"),
        (6, 3, "r"),
        (6, 5, "r"),
        (7, 5, "r"),
        (7, 6, "r"),
        # floor 2
        (21, 22, "f2"),
        (21, 23, "f2"),
        (21, 27, "f2"),
        (25, 27, "f2"),
        (24, 27, "f2"),
        (22, 27, "f2"),
        (26, 27, "f2"),
        (23, 27, "f2")
    ]

    #=
    survival model
    =#
    ωs = Dict(
        # dangerous floor transition
        "ft" => 0.8,
        # in/out of main
        "iom" => 0.9,
        # right side of floor 1 
        "r" => 0.97,
        # left side of floor 1 
        "l" => 0.95,
        # floor 2
        "f2" => 0.9,
        # main hall
        "m" => 0.9
    )

    function my_add_edge!(g, i, j, ω)
        add_edge!(g, i, j)
        add_edge!(g, j, i)
        set_prop!(g, i, j, :ω, ω)
        set_prop!(g, j, i, :ω, ω)
    end
    
    for (i, j, loc) in edge_list
        my_add_edge!(g, i, j, ωs[loc])
    end
    
    #=
    reward model
    =#
    for v = 1:nv(g)
        # BIG galleries
        if v in [24, 26, 25, 6, 7]
            set_prop!(g, v, :r, 2.0/3)
        # med galleries
        elseif v in [5, 4, 10, 11, 14, 12, 17]
            set_prop!(g, v, :r, 1.0/3)
        # small galleries
        elseif v in [3, 9, 16, 15, 13, 18, 22]
            set_prop!(g, v, :r, 1.0)
        # corners / hiddenish
        elseif v in [19, 20, 23, 8]
            set_prop!(g, v, :r, 1.0/10)
        else
            set_prop!(g, v, :r, 0.0)
        end
    end
	set_prop!(g, 1, :r, 0.0)

	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function generate_random_top(
	nb_nodes::Int,
	nb_robots::Int;
	survival_model::Symbol=:random,
	p::Float64=0.3
)
	@assert survival_model in [:random, :binary]

	# generate structure of the graph
	g_er = erdos_renyi(nb_nodes, p, is_directed=false)
    if ! is_connected(g_er)
        @warn "not connected, trying again. consider increasing p"
        return generate_random_top(
            nb_nodes, nb_robots, survival_model=survival_model, p=p
        )
    end
	g = MetaDiGraph(nb_nodes)

	for ed in edges(g_er)
		add_edge!(g, ed.src, ed.dst)
		add_edge!(g, ed.dst, ed.src)
		if survival_model == :random
			ω = rand()
		elseif survival_model == :binary
			ω = rand([0.4, 0.8])
		end
		set_prop!(g, ed.src, ed.dst, :ω, ω)
		set_prop!(g, ed.dst, ed.src, :ω, ω)
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand())
	end
	set_prop!(g, 1, :r, 0.0)

	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function generate_manual_top(nb_robots::Int)
	Random.seed!(1337)
    g = MetaDiGraph(11)
	lo_risk = 0.95
	hi_risk = 0.70
	edge_list = [
		# branch
		(1, 9, lo_risk),
		# branch
		(1, 10, hi_risk),
		(10, 11, hi_risk),
		# cycle
		(1, 8, lo_risk),
		(8, 7, lo_risk),
		(7, 6, hi_risk),
		(6, 4, hi_risk),
		(4, 3, hi_risk),
		(3, 2, lo_risk),
		(2, 1, lo_risk),
		# bridge off cycle
		(4, 5, 1.0),
		# shortcut in cycle
		(7, 3, lo_risk),
	]
	reward_dict = Dict(
		1=>1, 10=>5, 11=>25, 9=>3, 2=>40, 3=>10, 7=>4, 8=>4, 6=>10, 4=>35, 5=>34
	)
	for (i, j, p_s) in edge_list
		add_edge!(g, i, j, :ω, p_s)
		add_edge!(g, j, i, :ω, p_s)
	end
	for v = 1:nv(g)
		set_prop!(g, v, :r, 1.0*reward_dict[v])
	end
	set_prop!(g, 1, :r, 0.0)

	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function toy_problem()
	nb_robots = 2

	g = MetaDiGraph(5)
	rewards = zeros(5)
	rewards[3] = 1
	rewards[4] = 4
	rewards[5] = 5
	edge_list = [ # node i, node j, # dangers
		(1, 2, 2),
		(2, 3, 1),
		(1, 3, 1),
		(3, 4, 2),
		(2, 4, 0),
		(4, 5, 3)
	]
    ω_tornado = 0.1 # prob tornado causes failure
	for (i, j, nb_dangers) in edge_list
        add_edge!(g, i, j)
        add_edge!(g, j, i)
        set_prop!(g, i, j, :ω, (1 - ω_tornado) ^ nb_dangers)
        set_prop!(g, j, i, :ω, (1 - ω_tornado) ^ nb_dangers)
    end
	for v = 1:nv(g)
		set_prop!(g, v, :r, rewards[v])
	end
	set_prop!(g, 1, :r, 0.0)

	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function toy_starish_top(nb_nodes::Int; seed::Int=1337)
	Random.seed!(seed)

	g = MetaDiGraph(star_graph(nb_nodes))

	# add another layer
	@assert degree(g)[1] == 2*(nb_nodes-1) # first node is center
	for v = 2:nb_nodes
		add_vertex!(g)
		add_edge!(g, nb_nodes + v - 1, v)
		add_edge!(g, v, nb_nodes + v - 1)
	end

	# assign survival probabilities
	for ed in edges(g)
		set_prop!(g, ed, :ω, rand())
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, 0.1 + rand())
	end

	return TOP(nv(g), g, 1)
end

# easy way to make a graph connected.
function remove_isolated_nodes(g)
    non_isolated = [v for v in vertices(g) if degree(g, v) > 0]
    return induced_subgraph(g, non_isolated)[1]  # Returns (new_graph, vertex_map)
end

function block_model(
	nb_vertices::Vector{Int},
    nb_robots::Int,
	P::Matrix{Float64},
	r_distn::Vector{<:Distribution},
	ω_distn::Matrix{<:Distribution}
)
	r_distn = Truncated.(r_distn, 0.0, Inf)
	ω_distn = Truncated.(ω_distn, 0.0, 1.0)

	# number of communities
	nb_comm = length(nb_vertices)
	n = sum(nb_vertices) + 1 # for depot node

	# mapping for community membership
	#   e.g. θ[3] gives community membership of vertex 3
	θ = vcat(
		[0], # depot node special
		vcat([[c for v = 1:nb_vertices[c]] for c = 1:nb_comm]...)
	)

	# plus one for the depot node
	g = MetaDiGraph(SimpleDiGraph(n))

	for u = 2:n
		r = rand(r_distn[θ[u]])
		set_prop!(g, u, :r, r)

		for v = (u+1):n
			# assign edge?
			p = P[θ[u], θ[v]]

			if rand() < p
				add_edge!(g, u, v)
				add_edge!(g, v, u)

				ω = rand(ω_distn[θ[u], θ[v]])
				set_prop!(g, u, v, :ω, ω)
				set_prop!(g, v, u, :ω, ω)
			end
		end
	end

	# depot node
	set_prop!(g, 1, :r, 0.0)
	for c = 1:length(nb_vertices)
		u = findfirst(θ .== c)
		add_edge!(g, u, 1)
		add_edge!(g, 1, u)

		set_prop!(g, 1, u, :ω, 1.0)
		set_prop!(g, u, 1, :ω, 1.0)
	end

    g = remove_isolated_nodes(g)

    if ! is_connected(g)
        return block_model(nb_vertices, P, r_distn, ω_distn)
    end

    return TOP(nv(g), g, nb_robots)
end

function complete_graph_top(
	nb_nodes::Int, nb_robots::Int, r_distn::Distribution, w_distn::Distribution
)
	r_distn = Truncated(r_distn, 0.0, Inf)
	w_distn = Truncated(w_distn, 0.0, 1.0)

	g = MetaDiGraph(complete_graph(nb_nodes))
	for v = 1:nv(g)
		set_prop!(g, v, :r, rand(r_distn))
	end
	for ed in edges(g)
		set_prop!(g, ed.src, ed.dst, :ω, rand(w_distn))
		set_prop!(g, ed.dst, ed.src, :ω, rand(w_distn))
	end
	set_prop!(g, 1, :r, 0.0)
    return TOP(nv(g), g, nb_robots)
end
