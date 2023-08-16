function darpa_urban_environment(nb_robots::Int)
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
    # compute max one-hop 𝔼[reward]
    one_hop_𝔼_r = zeros(nv(g))
    for v = 1:nv(g)
        us = neighbors(g, v)
        one_hop_𝔼_r[v] = maximum(get_ω(g, u, v) * get_r(g, v) for u in us)
    end
	return TOP(
               nv(g),
               g,
               nb_robots,
               maximum(one_hop_𝔼_r)
             )
end
