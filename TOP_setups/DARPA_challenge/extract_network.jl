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

# ╔═╡ 3d809d67-aa77-4a3a-8857-c86b80e8fba6
begin
	g = MetaGraph(SimpleGraph(48))
	
	#=
	edge list (see drawing)
	m = main traversal
	h = doorway traversal
	=#
	edge_list = [
		#=
		major transitions
		=#
		## FLOOR 1
		# zone A
		(1, 2, :m),
		(2, 3, :m),
		(3, 12, :m),
		(3, 5, :m),   # A <-> B
		(12, 15, :m), # A <-> D
		# zone B
		(5, 6, :m),
		(5, 18, :m),  # B <-> C
		# zone C
		(18, 19, :m),
		(18, 24, :m),
		# zone D
		(15, 26, :m),
		(26, 30, :m),
		(26, 27, :m),
		(30, 31, :m), # D <-> E
		# zone E
		(31, 32, :m),
		(31, 34, :m),
		(32, 33, :m),
		(33, 31, :m),
		(34, 36, :m),
		## FLOOR 2
		(39, 40, :m),
		(40, 46, :m),
		(46, 48, :m),
		#=
		hallway transitions
		=#
		## FLOOR 1
		# zone A
		(3, 4, :h),
		(3, 11, :h),
		(12, 13, :h),
		(12, 14, :h),
		# zone B
		(6, 7, :h),
		(7, 8, :h),
		(7, 9, :h),
		(7, 10, :h),
		# zone C
		(19, 20, :h),
		(19, 21, :h),
		(19, 22, :h),
		(22, 23, :h),
		# zone D
		(15, 16, :h),
		(15, 17, :h),
		(15, 25, :h),
		(26, 29, :h),
		(27, 28, :h),
		# zone E
		(34, 35, :h),
		(36, 37, :h),
		(36, 38, :h),
		## FLOOR 2
		(40, 41, :h),
		(40, 42, :h),
		(40, 43, :h),
		(41, 45, :h),
		(41, 46, :h),
		(46, 47, :h),
		(46, 44, :h),
		#=
		floor transitions
		=#
		(39, 1, :s)
	]

	# g = gas
	# c = cell phone
	# b = backpack
	# v = vent
	# s = survivor
	# omit if nothing
	artifact_type = Dict(
		# FLOOR 1
		# zone A
		4 => "g",
		11 => "b",
		12 => "b",
		13 => "v",
		# zone B 
		5 => "s",
		8 => "g",
		9 => "c",
		10 => "c",
		# zone C
		18 => "b",
		21 => "b",
		20 => "v",
		22 => "b",
		23 => "c",
		24 => "c",
		# zone D
		16 => "g",
		17 => "s",
		25=>"v",
		28=>"b",
		29=>"v",
		30=>"c",
		# zone E
		32=>"s",
		33=>"v",
		34=>"s",
		35=>"c",
		38=>"b",
		## FLOOR 2
		39=>"b",
		45=>"s",
		44=>"g",
		47=>"g",
		48=>"c",
		42=>"v",
		43=>"s"
	)

	# to help with visualization
	set_prop!(g, :pin, 
		Dict(
			1 => (0, 10),
			5 => (5, 10),
			6 => (5, 12),
			18 => (10, 10),
			15 => (3, 5),
			30 => (5, 3),
			34 => (6, 2)
		)
	)
	
	traversal_risks = Dict(
		:m => 0.9,
		:h => 0.7,
		:s => 0.5
	)
	
	for (i, j, t) in edge_list
		add_edge!(g, i, j)
		set_prop!(g, i, j, :ω, traversal_risks[t])
		set_prop!(g, i, j, :t, t)
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
	g
end

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

# ╔═╡ Cell order:
# ╠═d831ba24-3853-11ee-3060-b58f59ae05e4
# ╟─4e70a66e-d7dc-4510-9b14-b82cedb46c1b
# ╠═3d809d67-aa77-4a3a-8857-c86b80e8fba6
# ╠═118d7395-bd62-4a7e-ba81-095fcbf8f4b7
# ╠═e5f447a6-d604-4932-9d6d-92c8fca3e147
# ╠═5c7d0621-4085-4851-9322-8b30029261f2
