### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 4678e159-7dee-4013-9749-41e2f505777a
begin
	import Pkg; Pkg.activate()
	
	using CairoMakie, Graphs, Combinatorics, PlutoUI, LinearAlgebra, Random, StatsBase, ColorSchemes, Test
end

# ╔═╡ 2149006c-4de8-4c06-9bb4-558806f24cd1
TableOfContents()

# ╔═╡ 06460a99-f6ca-48c0-8f0d-ef081a498cf7
set_theme!(theme_minimal()); update_theme!(resolution=(500, 500))

# ╔═╡ 797adf94-2ca8-11ee-34ea-13dce83b4f5c
md"# ant colony optimization (ACO) for team orienteering problem (TOP)

## problem instance

from [here](https://www.mech.kuleuven.be/en/cib/op), under _The Team Orienteering Problem_, from Chao et al. this is problem set 4.

note: we'll assume the start and end are node 1?
"

# ╔═╡ 48338f22-3a1a-4534-ac4d-84cc7baa7725
struct TOP
    nb_nodes::Int
	nb_robots::Int
    X::Matrix{Float64}
    rewards::Vector{Float64}
	rewards_sum::Float64
    travel_costs::Matrix{Float64}
    travel_budget::Float64
	base_node_id::Int
end

# ╔═╡ 6205d5f0-da9d-45c0-9b6f-28b7ec766c72
# start, end nodes are 1 and n
function top_problem_instance(prob_name::String)
	ps_filename = joinpath("TOP_setups", "Set_100_234", prob_name)
	ps_file_lines = readlines(ps_filename)

	nb_nodes = parse(Int, split(ps_file_lines[1])[2])
	nb_robots = parse(Int, split(ps_file_lines[2])[2])
	travel_budget = parse(Float64, split(ps_file_lines[3])[2])

	X = zeros(2, nb_nodes) # coordinates
	rewards = zeros(Int, nb_nodes)
	for i = 1:nb_nodes
		line = split(ps_file_lines[3+i])
		rewards[i] = parse(Int, line[3])
		for k = 1:2
			X[k, i] = parse(Float64, line[k])
		end
	end

	travel_costs = [norm(X[:, i] - X[:, j]) for i in 1:nb_nodes, j in 1:nb_nodes]

	return TOP(
		nb_nodes, nb_robots, X, rewards, sum(rewards), travel_costs, travel_budget, 1
	)
end

# ╔═╡ 6f743d4e-758a-47c6-a48d-319b243bf798
top = top_problem_instance("p4.4.l.txt")

# ╔═╡ def3704d-45d5-47c4-929b-75fe71c825ee
function _draw_nodes!(
	fig, ax, top::TOP; 
	node_labels::Bool=false, highlight_node_list::Vector{Int}=Int[]
)
	ax.xlabel = "[length]"
	ax.ylabel = "[length]"
	ax.aspect = DataAspect()
	sp = scatter!(
		top.X[1, :], top.X[2, :], 
		color=top.rewards, markersize=12, colormap=ColorSchemes.Greens,
		strokewidth=1, strokecolor="black"
	)
	scatter!(top.X[1, top.base_node_id], top.X[2, top.base_node_id],
		marker=:+, color="red", markersize=20
	)
	if node_labels
	    for i = 1:top.nb_nodes
	        text!(top.X[1, i]+1/2, top.X[2, i]+1/2, color="black",
				text="$i", align=(:center, :center), fontsize=10
			)
	    end
	end
	if length(highlight_node_list) > 0
		scatter!(
			top.X[1, highlight_node_list], top.X[2, highlight_node_list], 
			strokecolor="red", markersize=12, strokewidth=2, color=("white", 0.0)
		)
	end
    Colorbar(fig[1, 2], sp, label="reward")
end

# ╔═╡ ed2f859e-420a-4992-a7a7-771f9c8b53b4
function viz_setup(
	top::TOP; 
	node_labels::Bool=false, highlight_node_list::Vector{Int}=Int[]
)
    fig = Figure()
    ax = Axis(fig[1, 1])
	ax.title = "TOP setup"
	_draw_nodes!(fig, ax, top, 
		node_labels=node_labels,highlight_node_list=highlight_node_list)
    fig
end

# ╔═╡ bcde78a3-f302-420a-857d-0713fdfff276
viz_setup(top, node_labels=false)

# ╔═╡ 700f73c9-c64a-43e5-90b9-3c9c5e593292
md"### data structure for (partial) solution"

# ╔═╡ 33474ee2-fbac-4fe0-be95-1b2f4692c670
begin
	mutable struct TOPSolution
		routes::Vector{Vector{Int}}
		node_visited::Vector{Bool}
	end
	
	function TOPSolution(top::TOP)
		tops = TOPSolution(
			[[top.base_node_id] for k = 1:top.nb_robots],
			[false for i = 1:top.nb_nodes]
		)
		tops.node_visited[top.base_node_id] = true
		return tops
	end
end

# ╔═╡ af3fcce1-314e-44aa-b621-a6434ce6c13c
toy_soln = TOPSolution(top)

# ╔═╡ 767aecc9-aead-4634-a43b-1382ea1386e6
function extend_route!(soln::TOPSolution, k::Int, v::Int)
	push!(soln.routes[k], v)
	soln.node_visited[v] = true
end

# ╔═╡ 59ed1b10-407c-4b64-ad73-ebf27da92a81
md"### route cost
start node must be included in the route.
"

# ╔═╡ 49149a54-a135-4d27-a93d-28ce560b0489
function route_cost(route::Vector{Int}, top::TOP)
	cost = 0.0
	for i = 1:length(route) - 1
		cost += top.travel_costs[route[i], route[i+1]]
	end
	return cost
end

# ╔═╡ 5b193227-9c70-48cb-b3d7-fe95b58b1cb1
route_cost(tops::TOPSolution, k::Int, top::TOP) = route_cost(tops.routes[k], top)

# ╔═╡ 63c44369-195d-469d-be05-ac4eb8d4b50e
begin
	extend_route!(toy_soln, 2, 19)
	extend_route!(toy_soln, 2, 21)
	@test route_cost(toy_soln, 2, top) == top.travel_costs[1, 19] + top.travel_costs[19, 21]
end

# ╔═╡ ee098886-bbd0-4939-8707-6eaed495bb7e
@test route_cost([1, 2], top) == top.travel_costs[1, 2]

# ╔═╡ 127f071b-1f14-4b86-8d6a-5f440052d2e3
@test route_cost([1, 2, 4], top) == top.travel_costs[1, 2] + top.travel_costs[2, 4]

# ╔═╡ bacbbcf1-fa22-453c-8e28-44355a1e8037
md"### sanity check on proposed solution"

# ╔═╡ 134dcca6-13f6-41d4-b1e0-13aea5d55355
function verify_solution(tops::TOPSolution, top::TOP)
	# for each robot...
	for k = top.nb_robots
		# start, end at base node
		@test tops.routes[k][1] == tops.routes[k][end] == top.base_node_id
		# route cost less than budget
		@test route_cost(tops, k, top) ≤ tops.travel_budget
		# all nodes on route marked as visisted
		@test all([tops.node_visisted[v] for v in tops.routes[k]])
	end
	# all nodes in routes marked as visisted.
	# all nodes not in routes marked as not visisted
	all_nodes_in_routes = unique(vcat(tops.routes...))
	@test all(tops.node_visisted[all_nodes_in_routes])
	@test sum(.! tops.node_visisted) == top.nb_nodes - length(all_nodes_in_routes)
end

# ╔═╡ 82dbf8d6-0810-4219-90d9-5cf3c83eac51
md"### team fitness function

judges quality of paths collectively---the sum of rewards collected among all robots.
"

# ╔═╡ c3db3a44-bd33-41f0-9bdd-44d88874f00b
# handles redundance in routes.
function team_fitness(soln::TOPSolution, top::TOP)
	return sum(top.rewards[soln.node_visited]) / top.rewards_sum
end

# ╔═╡ 45014e4d-9ca3-436e-afbb-6180f665ee74
begin
	extend_route!(toy_soln, 3, 13)
	@test team_fitness(toy_soln, top) ≈ sum(top.rewards[[1, 19, 21, 13]]) / sum(top.rewards)
end

# ╔═╡ a7ee000f-65a8-487c-8231-c1651e4cf3ee
md"## ant colony optimization

"

# ╔═╡ 62ccf17d-3e8b-4e72-85f8-9f8836372ca7
md"### heuristic for growing partial solutions

defined appeal of traveling i -> j
"

# ╔═╡ c9fa28f5-702a-41e6-94aa-bcb9e96caa78
function _η(i::Int, j::Int, top::TOP)
	# TODO: if generic start, end --> implement θ_ij
	if i == j
		return 0.0
	else
		return top.rewards[j] / top.travel_costs[i, j] # reward per travel cost
	end
end

# ╔═╡ 33bea28b-0457-4966-972f-2b80d5c90816
const η = [_η(i, j, top) for i = 1:top.nb_nodes, j = 1:top.nb_nodes]

# ╔═╡ a78d1b7f-aa39-4e84-9e1f-34c39cdfe514
md"visualize... note, this is not symmetric, so flawed..."

# ╔═╡ e005bb5a-5432-4604-bbb8-4b9d34ae248d
function viz_edge_labels(top::TOP, edge_labels::Matrix{Float64}; title::String="")
    fig = Figure()
    ax = Axis(fig[1, 1])
	ax.title = title
	for u = 1:top.nb_nodes
		for v = 1:top.nb_nodes
			lines!([top.X[1, u], top.X[1, v]], 
				   [top.X[2, u], top.X[2, v]], 
				color=("black", edge_labels[u, v] / maximum(edge_labels))
			)
		end
	end
	_draw_nodes!(fig, ax, top)
	fig
end

# ╔═╡ f12a4dfc-94c8-4102-8aac-bd721d9cb019
viz_edge_labels(top, η, title="heuristic, η")

# ╔═╡ d6add022-ebe3-4c87-8e88-7ed2ff5f7b5c
md"### build candidate set of nodes for extending partial solutions

exclude the base node. this will be inferred to be the last. depends on robot b/c of its travel budget.
"

# ╔═╡ 3fcda734-70d8-4704-958a-b5ee276fde34
# has node v been visited in the routes?
function node_visited(v::Int, routes::Vector{Vector{Int}}, top::TOP)
	for k = 1:top.nb_robots
		if v in routes[k]
			return true
		end
	end
	return false
end

# ╔═╡ bd0d87c2-43d8-44bd-8ad0-58a55c1ea287
function next_node_candidates(
	partial_routes::Vector{Vector{Int}}, 
	robot_id::Int, 
	top::TOP
)
	# calculate cost expended by this robot so far
	travel_cost_so_far = route_cost(partial_routes[robot_id], top)
	# current node on which this robot sits
	u = partial_routes[robot_id][end]
	# build candidate list. loop thru all nodes.
	node_candidates = Int[]
	for v = 1:top.nb_nodes
		# exclude base
		if v == top.base_node_id
			continue
		end
		# exclude those visited already by ANY robot (incl. this one!)
		if node_visited(v, partial_routes, top)
			continue
		end

		# if got this far, node v hasn't been visited yet.
		# add if possible to travel to it then back to base node.
		if (travel_cost_so_far + top.travel_costs[u, v] + 
				top.travel_costs[v, top.base_node_id]) ≤ top.travel_budget
			push!(node_candidates, v)
		end
	end
	return node_candidates
	# TODO: make faster by keeping overall list of not-visisted nodes.
	#   update each time node chosen?
end

# ╔═╡ a0580015-f04c-40af-912c-39c510d1c596
md"let's test visually and by building a hueuristic-guided route."

# ╔═╡ fc37fc37-8916-48f8-830a-37d7b245ab4a
test_candidate_list = 
	next_node_candidates([[1], [1, 67, 42], [1, 97, 15], [1, 58]], 2, top)

# ╔═╡ dc49f03e-47c4-45ce-8745-53b5d2c7abf6
viz_setup(top, node_labels=true, highlight_node_list=test_candidate_list)

# ╔═╡ c3b9f562-05c5-46f0-aef9-42b0fa8859a3
md"### heuristic route viz"

# ╔═╡ 39a856d3-c14b-441c-b706-86e99c202c72
function heuristic_guided_routes(top::TOP, η::Matrix{Float64})
	routes = [[top.base_node_id] for k = 1:top.nb_robots]
	# for each robot, grow route until it succeeds
	for k = 1:top.nb_robots
		candidates = next_node_candidates(routes, k, top)
		while length(candidates) > 0
			# current node
			u = routes[k][end]
			# choose next candidate node to be the one with highest heuristic
			v = candidates[argmax(η[u, candidates])]
			push!(routes[k], v)
			# update candidate list
			candidates = next_node_candidates(routes, k, top)
		end
		push!(routes[k], 1)
	end
	return routes
end

# ╔═╡ ffd2099b-b366-4ecd-8b9a-706ec50965e9
hroutes = heuristic_guided_routes(top, η)

# ╔═╡ 6fa3d448-f3c2-4f77-80df-8d6078fc6c34
function viz_routes(routes::Vector{Vector{Int}}, top::TOP)
	fig = Figure()
	ax = Axis(fig[1, 1])
	_draw_nodes!(fig, ax, top)
	for k = 1:top.nb_robots
		lines!(top.X[1, routes[k]], top.X[2, routes[k]])
	end
	fig
end

# ╔═╡ dca42318-9a56-4d25-9317-3453a6bccdf1
viz_routes(hroutes, top)

# ╔═╡ 66efb614-8b7d-49ed-8e77-697a793f06e8
team_fitness(hroutes, top)

# ╔═╡ e02cf577-60bb-45f0-8739-0df6232aa14b
md"### extending a partial solution"

# ╔═╡ 134a8884-7467-4d2b-a433-85a46b7470f2
function extend_partial_solution!(
	partial_routes::Vector{Vector{Int}}, k::Int, top::TOP, 
	τ::Matrix{Float64}, η::Matrix{Float64}
)
	vs = next_node_candidates(partial_routes, k, top)
	# if no budget to visit other nodes...
	if length(vs) == 0
		push!(partial_routes[k], top.base_node_id)
		return true # done
	else
		u = partial_routes[k][end] # current node
		v = sample(vs, 
			ProbabilityWeights(
				[τ[u, v] * sqrt(η[u, v]) for v in vs]
			)
		)
		push!(partial_routes[k], v)
		return false # not done
	end
end

# ╔═╡ 865d698b-b226-4b3d-af07-567f91af2aff
extend_partial_solution!(hroutes, 1, top, ones(top.nb_nodes, top.nb_nodes), η)

# ╔═╡ 7b9cbad1-e433-439e-95d9-5a39fce063e7
md"### 🐜 time"

# ╔═╡ 226e41ca-43e8-41fa-9f67-9ec079b4a554
function ant_colony_opt(top::TOP; N_ants::Int=20, N_iters::Int=250, ρ::Float64=0.02)
	# initialize global best fitness and route
	global_best_fitness = -Inf
	global_best_routes = [[0]]
	
	# initialize pheremone
	τ = ones(top.nb_nodes, top.nb_nodes)
	for _ = 1:N_iters
		# initialize routes their costs
		routes     = [[[top.base_node_id] for k = 1:top.nb_robots] for a = 1:N_ants]
		fitnesses  = [-Inf  for a = 1:N_ants]

		#=
		each ant finds a route.
		sequential method.
		=#
		for a = 1:N_ants
			for k = 1:top.nb_robots
				route_complete = false
				while ! route_complete
					route_complete = extend_partial_solution!(routes[a], k, top, τ, η)
				end
				# checks
				@assert route_cost(routes[a][k], top) ≤ top.travel_budget
				@assert length(unique(routes[a][k])) == length(routes[a][k]) - 1
			end
			fitnesses[a] = team_fitness(routes[a], top)
		end
			
		#=
		get best routes found among ants. 
		TODO: add local search.
		=#
		id_best_ant = argmax(fitnesses)
		# TODO local search
		# locally_optimized_best_route = two_opt_route(routes[id_best_ant], op)
		best_routes = routes[id_best_ant]
		best_fitness = team_fitness(best_routes, top)

		if best_fitness > global_best_fitness
			global_best_fitness = best_fitness
			global_best_routes = deepcopy(best_routes)
		end

		#=
		pheremone evaporation
		=#
		τ .*= (1 - ρ)
		
		#=
		best ant lays pheremone
		=#
		for k = 1:top.nb_robots
			# loop over edges
			for i = 1:length(best_routes[k])-1
				# robot k hops from u to v...
				u = best_routes[k][i]
				v = best_routes[k][i+1]
				# deposity pheremone
				# alt. between using best fitness THIS iteration and global
				τ[u, v] += (rand() < 0.5) ? best_fitness : global_best_fitness
				τ[v, u] = τ[u, v] # symmetry
			end
		end

		# clip pheremone
		τ_max = global_best_fitness / ρ
		τ_min = (1 - 0.05 ^ (1/top.nb_nodes)) / ((top.nb_nodes/2 - 1) * 0.05 ^ (1/top.nb_nodes)) * τ_max
		for u = 1:top.nb_nodes
			for v = u+1:top.nb_nodes
				if τ[u, v] < τ_min
					τ[u, v] = τ[v, u] = τ_min
				end
				if τ[u, v] > τ_max
					τ[u, v] = τ[v, u] = τ_max
				end
			end
		end
	end
	# @assert issymmetric(τs)
	return global_best_routes, global_best_fitness, τ
end

# ╔═╡ ec547ba8-bfbd-46b5-b178-a2aad0d96e03
routes, fitness, τ = ant_colony_opt(top, N_ants=20, N_iters=150)

# ╔═╡ b9ab6cfd-723e-4a1a-9adb-a57a993ea41a
viz_routes(routes, top)

# ╔═╡ 84c394e3-9193-4e76-84f6-542f0fdb4735
viz_edge_labels(top, τ, title="pheremone, τ")

# ╔═╡ Cell order:
# ╠═4678e159-7dee-4013-9749-41e2f505777a
# ╠═2149006c-4de8-4c06-9bb4-558806f24cd1
# ╠═06460a99-f6ca-48c0-8f0d-ef081a498cf7
# ╟─797adf94-2ca8-11ee-34ea-13dce83b4f5c
# ╠═48338f22-3a1a-4534-ac4d-84cc7baa7725
# ╠═6205d5f0-da9d-45c0-9b6f-28b7ec766c72
# ╠═6f743d4e-758a-47c6-a48d-319b243bf798
# ╠═def3704d-45d5-47c4-929b-75fe71c825ee
# ╠═ed2f859e-420a-4992-a7a7-771f9c8b53b4
# ╠═bcde78a3-f302-420a-857d-0713fdfff276
# ╟─700f73c9-c64a-43e5-90b9-3c9c5e593292
# ╠═33474ee2-fbac-4fe0-be95-1b2f4692c670
# ╠═af3fcce1-314e-44aa-b621-a6434ce6c13c
# ╠═767aecc9-aead-4634-a43b-1382ea1386e6
# ╟─59ed1b10-407c-4b64-ad73-ebf27da92a81
# ╠═49149a54-a135-4d27-a93d-28ce560b0489
# ╠═5b193227-9c70-48cb-b3d7-fe95b58b1cb1
# ╠═63c44369-195d-469d-be05-ac4eb8d4b50e
# ╠═ee098886-bbd0-4939-8707-6eaed495bb7e
# ╠═127f071b-1f14-4b86-8d6a-5f440052d2e3
# ╟─bacbbcf1-fa22-453c-8e28-44355a1e8037
# ╠═134dcca6-13f6-41d4-b1e0-13aea5d55355
# ╟─82dbf8d6-0810-4219-90d9-5cf3c83eac51
# ╠═c3db3a44-bd33-41f0-9bdd-44d88874f00b
# ╠═45014e4d-9ca3-436e-afbb-6180f665ee74
# ╟─a7ee000f-65a8-487c-8231-c1651e4cf3ee
# ╟─62ccf17d-3e8b-4e72-85f8-9f8836372ca7
# ╠═c9fa28f5-702a-41e6-94aa-bcb9e96caa78
# ╠═33bea28b-0457-4966-972f-2b80d5c90816
# ╟─a78d1b7f-aa39-4e84-9e1f-34c39cdfe514
# ╠═e005bb5a-5432-4604-bbb8-4b9d34ae248d
# ╠═f12a4dfc-94c8-4102-8aac-bd721d9cb019
# ╟─d6add022-ebe3-4c87-8e88-7ed2ff5f7b5c
# ╠═3fcda734-70d8-4704-958a-b5ee276fde34
# ╠═bd0d87c2-43d8-44bd-8ad0-58a55c1ea287
# ╟─a0580015-f04c-40af-912c-39c510d1c596
# ╠═fc37fc37-8916-48f8-830a-37d7b245ab4a
# ╠═dc49f03e-47c4-45ce-8745-53b5d2c7abf6
# ╟─c3b9f562-05c5-46f0-aef9-42b0fa8859a3
# ╠═39a856d3-c14b-441c-b706-86e99c202c72
# ╠═ffd2099b-b366-4ecd-8b9a-706ec50965e9
# ╠═6fa3d448-f3c2-4f77-80df-8d6078fc6c34
# ╠═dca42318-9a56-4d25-9317-3453a6bccdf1
# ╠═66efb614-8b7d-49ed-8e77-697a793f06e8
# ╟─e02cf577-60bb-45f0-8739-0df6232aa14b
# ╠═134a8884-7467-4d2b-a433-85a46b7470f2
# ╠═865d698b-b226-4b3d-af07-567f91af2aff
# ╟─7b9cbad1-e433-439e-95d9-5a39fce063e7
# ╠═226e41ca-43e8-41fa-9f67-9ec079b4a554
# ╠═ec547ba8-bfbd-46b5-b178-a2aad0d96e03
# ╠═b9ab6cfd-723e-4a1a-9adb-a57a993ea41a
# ╠═84c394e3-9193-4e76-84f6-542f0fdb4735
