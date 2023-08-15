### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d831ba24-3853-11ee-3060-b58f59ae05e4
begin
	import Pkg; Pkg.activate()
	using Graphs, CairoMakie, MetaGraphs, GraphMakie, NetworkLayout, ColorSchemes
end

# ╔═╡ 4e70a66e-d7dc-4510-9b14-b82cedb46c1b
md"# TOP based on DARPA challenge

see [here](https://www.darpa.mil/program/darpa-subterranean-challenge).

we used the map from [here](https://github.com/subtchallenge/systems_urban_ground_truth)
"

# ╔═╡ 118d7395-bd62-4a7e-ba81-095fcbf8f4b7
edge_type_to_color = Dict(:m => "green", :h => "orange", :s => "red")

# ╔═╡ e5f447a6-d604-4932-9d6d-92c8fca3e147
begin
	_layout = Spring(; iterations=2000, C=3.5, pin=get_prop(g, :pin))
	layout = _layout(g)
end

# ╔═╡ 5c7d0621-4085-4851-9322-8b30029261f2
begin
	fig = Figure()
	ax = Axis(fig[1, 1], aspect=DataAspect())
	# hidespines!(ax)
	# hidedecorations!(ax)
	reward_color_scheme = ColorSchemes.viridis
	rewards = [get_prop(g, v, :r) for v in vertices(g)]
	crangescale = (0.0, round(maximum(rewards), digits=1))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]
	graphplot!(
		g, 
		layout=layout,
		node_size=35, 
		node_color=node_color, 
		edge_color=[edge_type_to_color[get_prop(g, ed, :t)] for ed in edges(g)],
		nlabels=["$v" for v in vertices(g)],
		nlabels_align=(:center, :center)
	)
	fig
end

# ╔═╡ 79022053-15c9-4c66-b537-d64fc8ec71b2
function darpa_urban_environment()
	g = MetaGraph(SimpleGraph(73))
	
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
	
	traversal_risks = Dict(
		:o => 0.5,
		:m => 0.95,
		:h => 0.75,
		:f => 0.4
	)
	
	for (i, j, t) in edge_list
		add_edge!(g, i, j)
		set_prop!(g, i, j, :ω, traversal_risks[t])
	end
	
	artifact_reward = Dict(
		"s" => 50,
		"c" => 25,
		"b" => 15,
		"g" => 5,
		"v" => 7
	)
	for v = 1:nv(g)
		r = (v in keys(artifact_type)) ? artifact_reward[artifact_type[v]] : 0.0
		set_prop!(g, v, :r, r)
	end
	return g
end

# ╔═╡ 80174cda-4f60-4901-9608-f557d8d6510e
my_g = darpa_urban_environment()

# ╔═╡ 260a1bb5-628e-4fad-965f-12e3ea195a36
graphplot(my_g)

# ╔═╡ Cell order:
# ╠═d831ba24-3853-11ee-3060-b58f59ae05e4
# ╟─4e70a66e-d7dc-4510-9b14-b82cedb46c1b
# ╠═118d7395-bd62-4a7e-ba81-095fcbf8f4b7
# ╠═e5f447a6-d604-4932-9d6d-92c8fca3e147
# ╠═5c7d0621-4085-4851-9322-8b30029261f2
# ╠═79022053-15c9-4c66-b537-d64fc8ec71b2
# ╠═80174cda-4f60-4901-9608-f557d8d6510e
# ╠═260a1bb5-628e-4fad-965f-12e3ea195a36
