### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate()
	using Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes
end

# ╔═╡ 6e7ce7a6-5c56-48a0-acdd-36ecece95933
function generate_graph(n::Int)
	# generate structure of the graph
	g = erdos_renyi(n, 0.4)
	g = MetaGraph(g)
	
	# assign survival probabilities
	for ed in edges(g)
		set_prop!(g, ed, :ω, rand())
	end

	# assign rewards
	for v in vertices(g)
		set_prop!(g, v, :r, rand())
	end
	return g
end

# ╔═╡ 58c9e986-88de-4f62-be7f-7b0b96b74a5c
g = generate_graph(20)

# ╔═╡ b7f68115-14ea-4cd4-9e96-0fa63a353fcf
function viz_graph(g::MetaGraph; nlabels::Bool=true)
	# assign node color based on rewards
	reward_color_scheme = ColorSchemes.acton
	rewards = [get_prop(g, v, :r) for v in vertices(g)]
	crangescale = (0.0, maximum(rewards))
	node_color = [get(reward_color_scheme, r, crangescale) for r in rewards]

	# assign edge color based on probability of survival
	survival_color_scheme = ColorSchemes.bamako
	edge_surivival_probs = [get_prop(g, ed.src, ed.dst, :ω) for ed in edges(g)]
	edge_color = [get(survival_color_scheme, p) for p in edge_surivival_probs]
	
	fig = Figure()
	ax = Axis(fig[1, 1])
	hidespines!(ax)
	hidedecorations!(ax)
	graphplot!(
		g, 
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
		@assert has_edge(g, path[i], path[i+1])
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
	else
		return π_robot_survives(g, path[1:id_path_giving_node_j])
	end
end

# ╔═╡ e9fc7773-1078-414d-aac6-0dfd9cee231a
path = [4, 14, 19, 5]

# ╔═╡ 1c075d70-23f6-4bae-9d4a-2a77e9f38a8e
typeof(findfirst(path .== 193))

# ╔═╡ 241eea88-7610-4a54-af23-316b3fdf9780
π_robot_survives(g, path)

# ╔═╡ 67706b5c-ef3f-48df-b2e2-ace159f814e1
π_robot_visits_node_j(g, path, 14)

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═6e7ce7a6-5c56-48a0-acdd-36ecece95933
# ╠═58c9e986-88de-4f62-be7f-7b0b96b74a5c
# ╠═b7f68115-14ea-4cd4-9e96-0fa63a353fcf
# ╠═74ce2e45-8c6c-40b8-8b09-80d97f58af2f
# ╠═926977f1-a337-4825-bfe4-ccc1a2e4cc93
# ╠═cdb0e3ec-426a-48f2-800f-f70cfc20492a
# ╠═1c075d70-23f6-4bae-9d4a-2a77e9f38a8e
# ╠═732e023a-048f-4cf4-beba-c14d10fe643f
# ╠═e9fc7773-1078-414d-aac6-0dfd9cee231a
# ╠═241eea88-7610-4a54-af23-316b3fdf9780
# ╠═67706b5c-ef3f-48df-b2e2-ace159f814e1
