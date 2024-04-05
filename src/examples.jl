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
		"s" => 50,
		"c" => 30,
		"b" => 20,
		"g" => 15,
		"v" => 12
	)
	for v = 1:nv(g)
		r = (v in keys(artifact_type)) ? artifact_reward[artifact_type[v]] : 0.0
		set_prop!(g, v, :r, r)
	end
	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function art_museum(nb_robots::Int)
	g = MetaDiGraph(SimpleDiGraph(27))
	edge_list = [
        # floor 1
        # main
        (1, 2),
        (2, 8),
        # left
        (2, 9),
        (9, 10),
        (9, 16),
        (8, 10),
        (10, 11),
        (11, 12),
        (11, 14),
        (16, 15),
        (14, 15),
        (12, 13),
        (14, 13),
        (12, 18),
        (17, 18),
        (17, 14),
        (20, 14),
        (14, 19),
        (20, 19),
        (2, 4),
        (2, 3),
        (4, 5),
        (5, 3),
        (6, 3),
        (6, 5),
        (7, 5),
        (7, 6),
        (8, 6),
        # floor transition
        (2, 21),
        # floor 2
        (21, 22),
        (21, 23),
        (23, 22),
        (21, 27),
        (25, 27),
        (24, 27),
        (22, 27),
        (26, 27),
        (23, 27)
   ]
	
    for (i, j) in edge_list
        add_edge!(g, i, j)
        add_edge!(g, j, i)
        ω = 0.98
        set_prop!(g, i, j, :ω, ω)
        set_prop!(g, j, i, :ω, ω)
    end
    # floor transition (dangerous)
    set_prop!(g, 2, 21, :ω, 0.75)
    set_prop!(g, 21, 2, :ω, 0.75)
    # set rewards
    for v = 1:nv(g)
        if (v in [1, 2, 21, 27])
            set_prop!(g, v, :r, 0.0)
        else
            set_prop!(g, v, :r, sample([1, 5, 10, 30], ProbabilityWeights([40.0, 30.0, 10.0, 2.0])))
        end
    end
	return TOP(
               nv(g),
               g,
               nb_robots
             )
end

function generate_random_top(
	nb_nodes::Int,
	nb_robots::Int;
	survival_model=:random,
	p=0.3
)
	@assert survival_model in [:random, :binary]

	# generate structure of the graph
	g_er = erdos_renyi(nb_nodes, p, is_directed=false)
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
		set_prop!(g, v, :r, 0.1 + rand()) # reward too small, heuristic won't take it there.
	end

	# compute max one-hop 𝔼[reward]
    one_hop_𝔼_r = zeros(nv(g))
    for v = 1:nv(g)
        us = neighbors(g_er, v)
        one_hop_𝔼_r[v] = maximum(get_prop(g, u, v, :ω) * get_prop(g, v, :r) for u in us)
    end

	# for base node
	# set_prop!(g, 1, :r, 0.001)
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
