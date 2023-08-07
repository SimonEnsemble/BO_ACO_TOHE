### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate()
	using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random
end

# ╔═╡ 6e7ce7a6-5c56-48a0-acdd-36ecece95933
function generate_graph(n::Int; survival_model=:random)
	@assert survival_model in [:random, :binary]
	
	# generate structure of the graph
	g = erdos_renyi(n, 0.4)
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

# ╔═╡ 58c9e986-88de-4f62-be7f-7b0b96b74a5c
g = generate_graph(20, survival_model=:binary)

# ╔═╡ b7f68115-14ea-4cd4-9e96-0fa63a353fcf
function viz_graph(g::MetaGraph; nlabels::Bool=true, paths=[[]])
	# assign node color based on rewards
	reward_color_scheme = ColorSchemes.acton
	rewards = [get_prop(g, v, :r) for v in vertices(g)]
	crangescale = (0.0, maximum(rewards))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = ColorSchemes.bamako
	edge_surivival_probs = [get_prop(g, ed.src, ed.dst, :ω) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]

	# layout
	_layout = Spring(; iterations=20)
	layout = _layout(g)
	
	fig = Figure()
	ax = Axis(fig[1, 1])
	hidespines!(ax)
	hidedecorations!(ax)
	# plot paths as highlighted edges
	path_colors = ColorSchemes.Accent_4
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
			edge_color=(path_colors[p], 0.5),
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
viz_graph(g)

# ╔═╡ 926977f1-a337-4825-bfe4-ccc1a2e4cc93
function verify_path(path::Vector{Int}, g::MetaGraph)
	# can follow edges that exist in the graph
	for n = 1:length(path)-1
		@assert has_edge(g, path[n], path[n+1])
	end
	# TODO uniqueness of nodes visisted (depends on base situation)
end

# ╔═╡ cdb0e3ec-426a-48f2-800f-f70cfc20492a
function π_robot_survives(g::MetaGraph, path::Vector{Int})
	# path length, in terms of # edges
	ℓ = length(path) - 1
	# product of survival probabilities along the path (gotta survive all)
	return prod(
		get_prop(g, path[n], path[n+1], :ω)
			for n = 1:ℓ # n := edge along the path.
	)
end

# ╔═╡ 732e023a-048f-4cf4-beba-c14d10fe643f
function π_robot_visits_node_j(g::MetaGraph, path::Vector{Int}, j::Int)
	# which node in the path is node j? (possibly not there)
	id_path_giving_node_j = findfirst(path .== j)
	if isnothing(id_path_giving_node_j) # not in path
		return 0.0
	elseif id_path_giving_node_j == 1
		return 1.0 # umm survives at base fo sho
	else
		return π_robot_survives(g, path[1:id_path_giving_node_j])
	end
end

# ╔═╡ e7c955d6-ba17-4066-a737-e040c3016280
function random_path(g::MetaGraph, v_start::Int, n::Int)
	path = zeros(Int, n+1)
	path[1] = v_start
	for i = 1:n
		path[i+1] = sample([u for u in neighbors(g, path[i]) if ! (u in path)])
	end
	return path
end

# ╔═╡ ec757c86-2072-4cc2-a399-e4ef347c3c80
function expected_reward(g::MetaGraph, paths::Vector{Vector{Int}}, j::Int)
	# how robots are traveling?
	nb_robots = length(paths)
	# wut reward does this node offer?
	r = get_prop(g, j, :r)
	# construct Poisson binomial distribution
	pb = PoissonBinomial(
		[π_robot_visits_node_j(g, path, j) for path in paths]
	)
	# expected reward is (1 - prob(0 robots visit it)) * r
	return (1 - pdf(pb, 0)) * r
end

# ╔═╡ a1572e77-2126-443a-8da1-adcf4af01e87
function expected_reward(g::MetaGraph, paths::Vector{Vector{Int}})
	return sum(
		expected_reward(g, paths, v) for v in vertices(g)
	)
end

# ╔═╡ e9fc7773-1078-414d-aac6-0dfd9cee231a
path = random_path(g, 18, 3)

# ╔═╡ 8da34c11-8598-46d0-af29-bcf78d9d0e4e
viz_graph(g, paths=[path])

# ╔═╡ 20f4eb18-3d36-43e0-8e97-ed2bccc13f55
paths = [random_path(g, 18, 3), random_path(g, 11, 4)]

# ╔═╡ b2d3e870-c1df-4654-9b0c-9eae00673553
verify_path(path, g)

# ╔═╡ 241eea88-7610-4a54-af23-316b3fdf9780
π_robot_survives(g, path)

# ╔═╡ 67706b5c-ef3f-48df-b2e2-ace159f814e1
π_robot_visits_node_j(g, path, 14)

# ╔═╡ 12c1ebd2-6b18-4c69-ac04-35639737b5ab
viz_graph(g, paths=paths)

# ╔═╡ 80af87b1-6dde-4580-a675-311d8488a082
paths

# ╔═╡ 2023c03a-9596-4f3f-9a5b-e4c8f55ab185
pb = expected_reward(g, paths, 18)

# ╔═╡ 9e6d222b-c585-40b2-82c9-5d7b9f5b4e77
expected_reward(g, paths)

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═58c9e986-88de-4f62-be7f-7b0b96b74a5c
# ╠═b7f68115-14ea-4cd4-9e96-0fa63a353fcf
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╠═926977f1-a337-4825-bfe4-ccc1a2e4cc93
# ╠═cdb0e3ec-426a-48f2-800f-f70cfc20492a
# ╠═732e023a-048f-4cf4-beba-c14d10fe643f
# ╠═e7c955d6-ba17-4066-a737-e040c3016280
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
