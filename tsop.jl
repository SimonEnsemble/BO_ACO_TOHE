### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate()
	using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, PlutoUI
end

# ╔═╡ e136cdee-f7c1-4add-9024-70351646bf24
TableOfContents()

# ╔═╡ 613ad2a0-abb7-47f5-b477-82351f54894a
md"# MO-ACO of TSOP

MO-ACO = multi-objective ant colony optimization

TSOP = team survival orienteering problem

## generate problem instance
"

# ╔═╡ 6e7ce7a6-5c56-48a0-acdd-36ecece95933
function generate_graph(nb_nodes::Int; survival_model=:random)
	@assert survival_model in [:random, :binary]
	
	# generate structure of the graph
	g = erdos_renyi(nb_nodes, 0.3)
	g = MetaGraph(g)
	
	# assign survival probabilities
	if survival_model == :random
		for ed in edges(g)
			set_prop!(g, ed, :ω, rand())
		end
	else
		for ed in edges(g)
			set_prop!(g, ed, :ω, rand([0.2, 0.8]))
		end
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, rand())
	end
	return g
end

# ╔═╡ 184af2a6-d5ca-4cbc-8a1a-a172eaae472f
struct TOP
	g::MetaGraph
	nb_robots::Int
end

# ╔═╡ 8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
top = TOP(
	generate_graph(20, survival_model=:binary),
	3,         # number of robots
)

# ╔═╡ b7f68115-14ea-4cd4-9e96-0fa63a353fcf
function viz_setup(
	top::TOP; 
	nlabels::Bool=true, 
	paths=[[]],
	robots::Bool=true
)
	g = top.g
	robot_colors = ColorSchemes.Accent_4
	
	# assign node color based on rewards
	reward_color_scheme = ColorSchemes.acton
	rewards = [get_prop(g, v, :r) for v in vertices(g)]
	crangescale = (0.0, maximum(rewards))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = reverse(ColorSchemes.solar)
	edge_surivival_probs = [get_prop(g, ed.src, ed.dst, :ω) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]

	# layout
	_layout = Spring(; iterations=20)
	layout = _layout(g)
	
	fig = Figure()
	ax = Axis(fig[1, 1], aspect=DataAspect())
	hidespines!(ax)
	hidedecorations!(ax)
	# plot paths as highlighted edges
	for (p, path) in enumerate(paths)
		# represent path as a graph
		g_path = SimpleGraph(nv(g))
		for n = 1:length(path) - 1
			add_edge!(g_path, path[n], path[n+1])
		end
		graphplot!(
			g_path,
			layout=layout,
			node_size=0,
			edge_color=(robot_colors[p], 0.5),
			edge_width=10
		)
	end
	# plot graph with nodes and edges colored
	graphplot!(
		g, 
		layout=layout,
		node_size=35, 
		node_color=node_color, 
		edge_color=edge_color,
		nlabels=nlabels ? ["$v" for v in vertices(g)] : nothing,
		nlabels_align=(:center, :center)
	)
	if robots
		# start node = 1
		x = layout[1][1]
		y = layout[1][2]
		r = 0.15
		for i = 1:top.nb_robots
			θ = π/2 * (i - 1)
			scatter!([x + r*cos(θ)], [y + r*sin(θ)], 
				marker='✈',markersize=20, color=robot_colors[i])
		end
	end
	Colorbar(
		fig[0, 1], 
		colormap=reward_color_scheme, 
		vertical=false, 
		label="reward", 
		ticks=[0.0, round(crangescale[2], digits=1)]
	)
	Colorbar(
		fig[-1, 1], 
		colormap=survival_color_scheme, 
		vertical=false, 
		label="survival probability", 
		ticks=[0.0, 1.0]
	)

	fig
end

# ╔═╡ 74ce2e45-8c6c-40b8-8b09-80d97f58af2f
viz_setup(top)

# ╔═╡ e501d59e-336e-456d-8abb-bc663bd4899e
md"## computing survival probabilities"

# ╔═╡ 926977f1-a337-4825-bfe4-ccc1a2e4cc93
function verify_path(path::Vector{Int}, top::TOP)
	# can follow edges that exist in the graph
	for n = 1:length(path)-1
		@assert has_edge(top.g, path[n], path[n+1])
	end
	# TODO uniqueness of nodes visisted (depends on base situation)
end

# ╔═╡ cdb0e3ec-426a-48f2-800f-f70cfc20492a
function π_robot_survives(path::Vector{Int}, top::TOP)
	# path length, in terms of # edges
	ℓ = length(path) - 1
	# product of survival probabilities along the path (gotta survive all)
	return prod(
		get_prop(top.g, path[n], path[n+1], :ω)
			for n = 1:ℓ # n := edge along the path.
	)
end

# ╔═╡ 2f78b5b8-e996-4b65-b8cc-7b27e45242ec
function 𝔼_nb_robots_survive(paths::Vector{Vector{Int}}, top::TOP)
	return sum(π_robot_survives(path, top) for path in paths)
end

# ╔═╡ 732e023a-048f-4cf4-beba-c14d10fe643f
function π_robot_visits_node_j(path::Vector{Int}, j::Int, top::TOP)
	# if the first node in the path is j, survival probability is one.
	#  b/c survives at the base for sure.
	if path[1] == j
		return 1.0
	end
	# which node in the path is node j? (possibly not there)
	id_path_giving_node_j = findfirst(path .== j)
	if isnothing(id_path_giving_node_j)
		# case: node j not in path
		return 0.0
	else
		# case: node j in path
		#    then we gotta survive the path up till and including node j.
		# @assert path[id_path_giving_node_j] == j
		return π_robot_survives(path[1:id_path_giving_node_j], top)
	end
end

# ╔═╡ e7c955d6-ba17-4066-a737-e040c3016280
function random_path(n::Int, top::TOP)
	path = zeros(Int, n+1)
	path[1] = 1
	for i = 1:n
		next_candidates = [u for u in neighbors(top.g, path[i]) if ! (u in path)]
		if length(next_candidates) == 0
			break
		end
		path[i+1] = sample(next_candidates)
	end
	return path
end

# ╔═╡ ad1c64f5-94b6-4c51-b66d-7cbe77495b2b
md"## computing expected reward"

# ╔═╡ ec757c86-2072-4cc2-a399-e4ef347c3c80
function expected_reward(paths::Vector{Vector{Int}}, j::Int, top::TOP)
	# how many robots are traveling?
	nb_robots = length(paths)
	
	# wut reward does this node offer?
	r = get_prop(top.g, j, :r)

	# get probability that each robot visits this node
	π_visits = [π_robot_visits_node_j(path, j, top) for path in paths]
	
	# construct Poisson binomial distribution
	#   success prob's given in π_visits. 
	pb = PoissonBinomial(π_visits)
	
	# return expected reward
	#   = prob. node j visisted once or more * r
	#  note: either (i) 0 robots visit or (i) one or more robots visit.
	#   = (1 - prob(0 robots visit the node)) * r
	return (1 - pdf(pb, 0)) * r
end

# ╔═╡ a1572e77-2126-443a-8da1-adcf4af01e87
function expected_reward(paths::Vector{Vector{Int}}, top::TOP)
	return sum(
		expected_reward(paths, v, top) for v in vertices(top.g)
	)
end

# ╔═╡ e9fc7773-1078-414d-aac6-0dfd9cee231a
path = random_path(4, top)

# ╔═╡ 8da34c11-8598-46d0-af29-bcf78d9d0e4e
viz_setup(top, paths=[path])

# ╔═╡ 20f4eb18-3d36-43e0-8e97-ed2bccc13f55
paths = [random_path(3, top), random_path(4, top), random_path(2, top)]

# ╔═╡ b2d3e870-c1df-4654-9b0c-9eae00673553
verify_path(path, top)

# ╔═╡ 241eea88-7610-4a54-af23-316b3fdf9780
π_robot_survives(paths[1], top)

# ╔═╡ 67706b5c-ef3f-48df-b2e2-ace159f814e1
π_robot_visits_node_j(paths[1], 15, top)

# ╔═╡ 12c1ebd2-6b18-4c69-ac04-35639737b5ab
viz_setup(top, paths=paths)

# ╔═╡ 80af87b1-6dde-4580-a675-311d8488a082
paths

# ╔═╡ 2023c03a-9596-4f3f-9a5b-e4c8f55ab185
pb = expected_reward(paths, 18, top)

# ╔═╡ 9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
expected_reward(paths, top)

# ╔═╡ 1b5cfbae-7010-4e37-b8a8-f91df6577eeb
𝔼_nb_robots_survive(paths, top)

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c


# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═184af2a6-d5ca-4cbc-8a1a-a172eaae472f
# ╠═8bec0537-b3ca-45c8-a8e7-53ed2f0b39ad
# ╠═b7f68115-14ea-4cd4-9e96-0fa63a353fcf
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╟─e501d59e-336e-456d-8abb-bc663bd4899e
# ╠═926977f1-a337-4825-bfe4-ccc1a2e4cc93
# ╠═cdb0e3ec-426a-48f2-800f-f70cfc20492a
# ╠═2f78b5b8-e996-4b65-b8cc-7b27e45242ec
# ╠═732e023a-048f-4cf4-beba-c14d10fe643f
# ╠═e7c955d6-ba17-4066-a737-e040c3016280
# ╟─ad1c64f5-94b6-4c51-b66d-7cbe77495b2b
# ╠═ec757c86-2072-4cc2-a399-e4ef347c3c80
# ╠═a1572e77-2126-443a-8da1-adcf4af01e87
# ╠═e9fc7773-1078-414d-aac6-0dfd9cee231a
# ╠═8da34c11-8598-46d0-af29-bcf78d9d0e4e
# ╠═20f4eb18-3d36-43e0-8e97-ed2bccc13f55
# ╠═b2d3e870-c1df-4654-9b0c-9eae00673553
# ╠═241eea88-7610-4a54-af23-316b3fdf9780
# ╠═67706b5c-ef3f-48df-b2e2-ace159f814e1
# ╠═12c1ebd2-6b18-4c69-ac04-35639737b5ab
# ╠═80af87b1-6dde-4580-a675-311d8488a082
# ╠═2023c03a-9596-4f3f-9a5b-e4c8f55ab185
# ╠═9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
# ╠═1b5cfbae-7010-4e37-b8a8-f91df6577eeb
# ╠═9d44f37d-8c05-450a-a448-7be50387499c
