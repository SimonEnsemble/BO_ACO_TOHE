### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 4678e159-7dee-4013-9749-41e2f505777a
begin
	import Pkg; Pkg.activate()
	
	using CairoMakie, Graphs, Combinatorics, PlutoUI, LinearAlgebra, Random, StatsBase, ColorSchemes, Test, Printf
end

# ╔═╡ 2149006c-4de8-4c06-9bb4-558806f24cd1
TableOfContents()

# ╔═╡ 06460a99-f6ca-48c0-8f0d-ef081a498cf7
begin
	import AlgebraOfGraphics: set_aog_theme!, firasans
	set_aog_theme!(fonts=[firasans("Light"), firasans("Light")])
	the_resolution = (500, 380)
	update_theme!(
		fontsize=20, 
		linewidth=2,
		markersize=14,
		titlefont=firasans("Light"),
		resolution=the_resolution
	)
end

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
		color=top.rewards, markersize=12, colormap=ColorSchemes.grays,
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
		routes::Vector{Vector{Int}} # of all k robots
		node_visited::Vector{Bool}  # by any robot
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

# ╔═╡ 7254040a-d7c9-4f2b-a21c-ab4c99a5c95c
md"### extending a partial soln"

# ╔═╡ 767aecc9-aead-4634-a43b-1382ea1386e6
function extend_route!(soln::TOPSolution, robot_id::Int, node_id::Int)
	push!(soln.routes[robot_id], node_id)
	soln.node_visited[node_id] = true
	return nothing
end

# ╔═╡ ab5923d4-f428-4283-aa69-291a3730bc7a
function end_route!(soln::TOPSolution, robot_id::Int, top::TOP)
	push!(soln.routes[robot_id], top.base_node_id)
end

# ╔═╡ 59ed1b10-407c-4b64-ad73-ebf27da92a81
md"### route cost
start node must be included in the route.
"

# ╔═╡ 426023ec-dd44-4641-a5c9-a288f71dc9a4
function route_cost(route::Vector{Int}, top::TOP)
	cost = 0.0
	for i = 1:length(route) - 1
		cost += top.travel_costs[route[i], route[i+1]]
	end
	return cost
end

# ╔═╡ 49149a54-a135-4d27-a93d-28ce560b0489
function route_cost(soln::TOPSolution, robot_id::Int, top::TOP)
	return route_cost(soln.routes[robot_id], top)
end

# ╔═╡ 63c44369-195d-469d-be05-ac4eb8d4b50e
begin
	extend_route!(toy_soln, 2, 19)
	extend_route!(toy_soln, 2, 21)
	extend_route!(toy_soln, 1, 13)
	@test route_cost(toy_soln, 2, top) == top.travel_costs[1, 19] + top.travel_costs[19, 21]
	@test route_cost(toy_soln, 1, top) == top.travel_costs[1, 13]
end

# ╔═╡ bacbbcf1-fa22-453c-8e28-44355a1e8037
md"### verify a solution"

# ╔═╡ 134dcca6-13f6-41d4-b1e0-13aea5d55355
function verify_solution(tops::TOPSolution, top::TOP)
	# for each robot...
	for k = top.nb_robots
		# start, end at base node
		@assert tops.routes[k][1] == tops.routes[k][end] == top.base_node_id
		# route cost less than budget
		@assert route_cost(tops, k, top) ≤ top.travel_budget
		# all nodes on route marked as visisted
		@assert all([tops.node_visited[v] for v in tops.routes[k]])
		# each robot visits unique vertices. except for start and end are repeated
		@assert length(unique(tops.routes[k])) == length(tops.routes[k]) - 1
	end
	@assert length(tops.routes) == top.nb_robots
	@assert length(tops.node_visited) == top.nb_nodes
	# all nodes in routes marked as visisted.
	# all nodes not in routes marked as not visisted
	all_nodes_in_routes = unique(vcat(tops.routes...))
	@assert all(tops.node_visited[all_nodes_in_routes])
	@assert sum(.! tops.node_visited) == top.nb_nodes - length(all_nodes_in_routes)
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

# ╔═╡ bd0d87c2-43d8-44bd-8ad0-58a55c1ea287
function next_node_candidates(
	partial_soln::TOPSolution, 
	robot_id::Int, 
	top::TOP
)
	# calculate cost expended by this robot so far
	travel_cost_so_far = route_cost(partial_soln, robot_id, top)
	
	# u = current node on which this robot sits
	u = partial_soln.routes[robot_id][end]
	# build candidate list. loop thru all nodes.
	node_candidates = Int[]
	for v = 1:top.nb_nodes # v = next node
		# exclude base
		if v == top.base_node_id
			continue
		end
		# exclude those visited already by ANY robot
		if partial_soln.node_visited[v]
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
end

# ╔═╡ a0580015-f04c-40af-912c-39c510d1c596
md"let's test visually and by building a hueuristic-guided route."

# ╔═╡ 87b1d723-260e-4186-a18f-94cbb54e334d
begin
	new_toy_soln = TOPSolution(top)
	extend_route!(new_toy_soln, 2, 11)
	extend_route!(new_toy_soln, 2, 5)
end

# ╔═╡ fc37fc37-8916-48f8-830a-37d7b245ab4a
test_candidate_list = 
	next_node_candidates(new_toy_soln, 2, top)

# ╔═╡ dc49f03e-47c4-45ce-8745-53b5d2c7abf6
viz_setup(top, node_labels=true, highlight_node_list=test_candidate_list)

# ╔═╡ c3b9f562-05c5-46f0-aef9-42b0fa8859a3
md"### heuristic-constructed solution viz"

# ╔═╡ 39a856d3-c14b-441c-b706-86e99c202c72
function heuristic_guided_soln(top::TOP, η::Matrix{Float64})
	soln = TOPSolution(top)
	# for each robot, grow route until it succeeds
	for k = 1:top.nb_robots
		candidates = next_node_candidates(soln, k, top)
		while length(candidates) > 0
			# current node
			u = soln.routes[k][end]
			# choose next candidate node to be the one with highest heuristic
			v = candidates[argmax(η[u, candidates])]
			extend_route!(soln, k, v)
			# update candidate list
			candidates = next_node_candidates(soln, k, top)
		end
		end_route!(soln, k, top)
	end
	verify_solution(soln, top)
	return soln
end

# ╔═╡ ffd2099b-b366-4ecd-8b9a-706ec50965e9
h_soln = heuristic_guided_soln(top, η)

# ╔═╡ 66efb614-8b7d-49ed-8e77-697a793f06e8
h_fitness = team_fitness(h_soln, top)

# ╔═╡ 6fa3d448-f3c2-4f77-80df-8d6078fc6c34
function viz_soln(soln::TOPSolution, top::TOP)
	fig = Figure()
	ax = Axis(fig[1, 1])
	line_plots = []
	for k = 1:top.nb_robots
		push!(line_plots,
			lines!(top.X[1, soln.routes[k]], top.X[2, soln.routes[k]])
		)
	end
	_draw_nodes!(fig, ax, top)
	Legend(
		fig[2, 1], line_plots, ["robot $k" for k = 1:top.nb_robots], 
		orientation=:horizontal, tellwidth=false, tellheight=true,
		labelsize=12
	)
	fig
end

# ╔═╡ dca42318-9a56-4d25-9317-3453a6bccdf1
viz_soln(h_soln, top)

# ╔═╡ 4a1ce44a-5d74-43a5-b6f8-046e3cdbd358
md"### local search

#### 2-opt
💡 we visit the same node set, but change the order in which the nodes are visitsed (that's all). so reward collected stays the same.
see [Wikipedia](https://en.wikipedia.org/wiki/2-opt). 

"

# ╔═╡ 244e1a66-fcf4-4f30-a0d8-3883690fcdf3
function two_opt_route!(
	soln::TOPSolution, 
	robot_id::Int, 
	top::TOP; 
	verbose::Bool=false
)
	# get the current route, its length, and its cost
	route = soln.routes[robot_id]
	n = length(route)
    cost = route_cost(route, top) # will change later
	initial_cost = cost # will not change
	# keep trying to reduce the cost of the route...
    found_cost_reduction = true # to enter the while loop
    while found_cost_reduction
        found_cost_reduction = false # we'll flip this later if we do...
		# break route 1 -> ... -> n into three segments:
		# 1) 1   -> ... -> i
		# 2) i+1 -> ... -> j
		# 3) j+1 -> ... -> n
		# 2-opt re-constructs route as:
		#   1) follow segment (1)
		#   2) connect i to j
		#   2) follow segment (2) in reverse
		#   3) connect i+1 to j+1 and follow segment (3)
		# same set of nodes are visited.
		# if this route is shorter, we accept it.
        for i = 1:n-2 # end node cannot be swapped. gotta end there.
            for j = i+1:n-1 # any earlier node can be connected to last
                new_route = vcat(route[1:i], reverse(route[i+1:j]), route[j+1:end])
                new_cost = route_cost(new_route, top)
                if new_cost < cost
                    found_cost_reduction = true
                    cost = new_cost
                    route = new_route
                end
            end
        end
    end
	# assert there was a cost reduction
	@assert initial_cost ≥ cost
	if verbose
		if initial_cost > cost
			@printf("route %d cost: %.2f -> %.2f\n", robot_id, initial_cost, cost)
		end
	end
	# replace current route with the optimized one.
	soln.routes[robot_id] = route
	return cost # new cost
end

# ╔═╡ dac1d857-3ebc-4c76-b328-10c5f8349beb
function two_opt_routes!(soln::TOPSolution, top::TOP; verbose::Bool=false)
	init_fitness = team_fitness(soln, top)
	for robot_id = 1:top.nb_robots
		two_opt_route!(soln, robot_id, top, verbose=verbose)
	end
	@assert init_fitness ≈ team_fitness(soln, top) # check fitness doesn't change
end

# ╔═╡ 7f001653-99bb-4589-a0f2-1aa03db7f777
two_opt_routes!(h_soln, top, verbose=true)

# ╔═╡ 822462b0-bebb-4f58-aa28-a4b3ce63e799
viz_soln(h_soln, top)

# ╔═╡ ae03c18d-4a95-4c2c-99b4-fdf4f13ba192
md"#### insertion of other unvisited nodes (if possible)
"

# ╔═╡ 525e1e2b-f5f6-4914-91ef-81f99917240b
@info "above IN PROGRESS"

# ╔═╡ e02cf577-60bb-45f0-8739-0df6232aa14b
md"### extending a partial solution (for ACO)"

# ╔═╡ 134a8884-7467-4d2b-a433-85a46b7470f2
function extend_partial_solution!(
	partial_soln::TOPSolution, robot_id::Int, top::TOP, 
	τ::Matrix{Float64}, η::Matrix{Float64}
)
	vs = next_node_candidates(partial_soln, robot_id, top)
	# if no budget to visit other nodes...
	if length(vs) == 0
		end_route!(partial_soln, robot_id, top)
		return true # done
	else
		# current node
		u = partial_soln.routes[robot_id][end]
		# sample next node
		v = sample(vs, 
			ProbabilityWeights(
				[τ[u, v] * sqrt(η[u, v]) for v in vs]
			)
		)
		extend_route!(partial_soln, robot_id, v)
		return false # not done
	end
end

# ╔═╡ 865d698b-b226-4b3d-af07-567f91af2aff
extend_partial_solution!(hroutes, 1, top, ones(top.nb_nodes, top.nb_nodes), η)

# ╔═╡ 7b9cbad1-e433-439e-95d9-5a39fce063e7
md"### 🐜 ACO"

# ╔═╡ c367f543-187f-40fe-9a06-cdbcf845066e
function evaporate_pheremone!(τ::Matrix{Float64}, ρ::Float64)
	τ .*= (1 - ρ)
end

# ╔═╡ 299f4228-cb24-4a59-8aab-b8c2e8a2e676
function deposit_pheremone!(τ::Matrix{Float64}, soln::TOPSolution, fitness::Float64)
	for k = 1:top.nb_robots
		# loop over edges
		for i = 1:length(soln.routes[k]) - 1
			# robot k hops from u to v...
			u = soln.routes[k][i]
			v = soln.routes[k][i+1]
			# deposity pheremone
			τ[u, v] += fitness
			τ[v, u] = τ[u, v] # symmetry
		end
	end
	return nothing
end

# ╔═╡ e916ba8a-8de3-4e1e-9d9e-c24090d1578c
function min_max_pheremone!(
	τ::Matrix{Float64}, 
	global_best_fitness::Float64, 
	ρ::Float64,
	top::TOP
)
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

# ╔═╡ 2f5687cc-657f-48d3-94ce-6359710b6385
struct ACOResult
	top::TOP
	nb_iters::Int
	global_best_soln::TOPSolution
	global_best_fitness::Float64
	τ::Matrix{Float64}
	fitness_over_iters::Vector{Float64}
end

# ╔═╡ 226e41ca-43e8-41fa-9f67-9ec079b4a554
function ant_colony_opt(
	top::TOP;                  # problem instance
	nb_ants::Int=20,           # number of ants to use
	nb_iters::Int=250,         # number of iterations
	ρ::Float64=0.02,           # pheremone evaporation rate
	pheremone_on::Bool=true,   # false to make it random search
	verify_solns::Bool=true    # safe but slows down.
)
	# initialize global best soln and fitness
	global_best_soln    = [[0]]
	global_best_fitness = -Inf
	fitness_over_iters  = zeros(nb_iters)
	
	# initialize pheremone
	τ = ones(top.nb_nodes, top.nb_nodes)
	for iter = 1:nb_iters
		# initialize solutions their fitnesses for this iteration
		solns      = [TOPSolution(top) for a = 1:nb_ants]
		fitnesses  = [-Inf             for a = 1:nb_ants]

		#=
		each ant finds a TOP solution.
		sequential method for determining vehicle routes.
		=#
		for a = 1:nb_ants
			for k = 1:top.nb_robots
				route_complete = false
				while ! route_complete
					route_complete = extend_partial_solution!(solns[a], k, top, τ, η)
				end
			end
			fitnesses[a] = team_fitness(solns[a], top)
			if verify_solns
				verify_solution(solns[a], top)
			end
		end
			
		#=
		get best routes found among ants. 
		TODO: add local search.
		=#
		id_best_ant = argmax(fitnesses)
		# TODO local search
		# locally_optimized_best_route = two_opt_route(routes[id_best_ant], op)
		iter_best_soln    = solns[id_best_ant]
		iter_best_fitness = team_fitness(iter_best_soln, top)

		if iter_best_fitness > global_best_fitness
			global_best_fitness = iter_best_fitness
			global_best_soln = deepcopy(iter_best_soln)
		end

		#=
		evaporate, deposit pheremone
		=#
		if pheremone_on
			evaporate_pheremone!(τ, ρ)
			
			# best ant lays pheremone
			if rand() < 0.5
				deposit_pheremone!(τ, global_best_soln, global_best_fitness)
			else
				deposit_pheremone!(τ, iter_best_soln,   iter_best_fitness)
			end
			min_max_pheremone!(τ, global_best_fitness, ρ, top)
		end

		# track progress
		fitness_over_iters[iter] = iter_best_fitness
	end
	@assert issymmetric(τ)
	return ACOResult(
		top,
		nb_iters,
		global_best_soln,
		global_best_fitness, 
		τ, 
		fitness_over_iters
	)
end

# ╔═╡ ec547ba8-bfbd-46b5-b178-a2aad0d96e03
aco_res = ant_colony_opt(top, nb_ants=20, nb_iters=1000, pheremone_on=true)

# ╔═╡ 647b03bb-329f-43f5-ac17-74964cffaa70
function viz_trajectory(aco_res::ACOResult, baseline_fitness::Float64)
	fig = Figure()
	ax = Axis(
		fig[1, 1], 
		xlabel="iteration", 
		ylabel="fitness\n(of iteration-best solution)"
	)
	hlines!([baseline_fitness], color="gray", linestyle=:dash)
	lines!(1:aco_res.nb_iters, aco_res.fitness_over_iters)
	fig
end

# ╔═╡ 354cb62d-d99b-4c96-8a4e-c544417a3428
viz_trajectory(aco_res, hfitness)

# ╔═╡ b9ab6cfd-723e-4a1a-9adb-a57a993ea41a
viz_soln(aco_res.global_best_soln, top)

# ╔═╡ 84c394e3-9193-4e76-84f6-542f0fdb4735
viz_edge_labels(top, aco_res.τ, title="pheremone, τ")

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
# ╟─7254040a-d7c9-4f2b-a21c-ab4c99a5c95c
# ╠═767aecc9-aead-4634-a43b-1382ea1386e6
# ╠═ab5923d4-f428-4283-aa69-291a3730bc7a
# ╟─59ed1b10-407c-4b64-ad73-ebf27da92a81
# ╠═426023ec-dd44-4641-a5c9-a288f71dc9a4
# ╠═49149a54-a135-4d27-a93d-28ce560b0489
# ╠═63c44369-195d-469d-be05-ac4eb8d4b50e
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
# ╠═bd0d87c2-43d8-44bd-8ad0-58a55c1ea287
# ╟─a0580015-f04c-40af-912c-39c510d1c596
# ╠═87b1d723-260e-4186-a18f-94cbb54e334d
# ╠═fc37fc37-8916-48f8-830a-37d7b245ab4a
# ╠═dc49f03e-47c4-45ce-8745-53b5d2c7abf6
# ╟─c3b9f562-05c5-46f0-aef9-42b0fa8859a3
# ╠═39a856d3-c14b-441c-b706-86e99c202c72
# ╠═ffd2099b-b366-4ecd-8b9a-706ec50965e9
# ╠═66efb614-8b7d-49ed-8e77-697a793f06e8
# ╠═6fa3d448-f3c2-4f77-80df-8d6078fc6c34
# ╠═dca42318-9a56-4d25-9317-3453a6bccdf1
# ╟─4a1ce44a-5d74-43a5-b6f8-046e3cdbd358
# ╠═244e1a66-fcf4-4f30-a0d8-3883690fcdf3
# ╠═dac1d857-3ebc-4c76-b328-10c5f8349beb
# ╠═7f001653-99bb-4589-a0f2-1aa03db7f777
# ╠═822462b0-bebb-4f58-aa28-a4b3ce63e799
# ╟─ae03c18d-4a95-4c2c-99b4-fdf4f13ba192
# ╠═525e1e2b-f5f6-4914-91ef-81f99917240b
# ╟─e02cf577-60bb-45f0-8739-0df6232aa14b
# ╠═134a8884-7467-4d2b-a433-85a46b7470f2
# ╠═865d698b-b226-4b3d-af07-567f91af2aff
# ╟─7b9cbad1-e433-439e-95d9-5a39fce063e7
# ╠═c367f543-187f-40fe-9a06-cdbcf845066e
# ╠═299f4228-cb24-4a59-8aab-b8c2e8a2e676
# ╠═e916ba8a-8de3-4e1e-9d9e-c24090d1578c
# ╠═2f5687cc-657f-48d3-94ce-6359710b6385
# ╠═226e41ca-43e8-41fa-9f67-9ec079b4a554
# ╠═ec547ba8-bfbd-46b5-b178-a2aad0d96e03
# ╠═647b03bb-329f-43f5-ac17-74964cffaa70
# ╠═354cb62d-d99b-4c96-8a4e-c544417a3428
# ╠═b9ab6cfd-723e-4a1a-9adb-a57a993ea41a
# ╠═84c394e3-9193-4e76-84f6-542f0fdb4735
