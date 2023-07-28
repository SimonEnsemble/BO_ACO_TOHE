### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ 537ca880-870b-4626-a38b-c1c33a71d8c1
begin
	import Pkg; Pkg.activate()
	using JuMP
	import GLPK
	import Random
	using CairoMakie, Graphs, Combinatorics, PlutoUI, LinearAlgebra, Random
end

# ╔═╡ 5f9ea40e-5c04-451f-8552-a06fc3532986
TableOfContents()

# ╔═╡ c95b7265-6d0b-4b1a-8db8-2f232bd0a64d
md"# the traveling salesman problem (TSP)

## generate a map of cities
first, generate the coordinates of the cities (this way triangle inequality will be satisified).
"

# ╔═╡ f4352476-0820-4603-b8b9-2219a54f0e87
function generate_towns(n::Int; random_seed::Int=1337)
	rng = Random.MersenneTwister(random_seed)
    x = 100 * rand(rng, n)
    y = 100 * rand(rng, n)
	return x, y
end

# ╔═╡ 622fe6ed-707a-4c88-a791-d11c031d2d37
x, y = generate_towns(30)

# ╔═╡ c1c58fc8-949f-4a02-b2f0-e8c3531e6517
md"compute distance matrix"

# ╔═╡ bf2588f6-1b6d-11ee-3729-c3d23f30a765
function distance_matrix(x::Vector{Float64}, y::Vector{Float64})
	n = length(x)
    C = [sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2) for i in 1:n, j in 1:n]
	@assert issymmetric(C)
	return C
end

# ╔═╡ 85e5731c-0050-4fcf-b229-3d26891ea3e7
C = distance_matrix(x, y)

# ╔═╡ b8df9338-e8a1-4c09-81b4-efbc7d078f30
md"visualize location of cities"

# ╔═╡ 00904c71-51b7-4d57-ae51-b6f925fc3a6a
begin
	function viz_setup(x, y)
		fig = Figure()
		ax = Axis(fig[1, 1])
		scatter!(x, y, color="green", markersize=25)
		hidedecorations!(ax)
		hidespines!(ax)
		fig
	end
	
	viz_setup(x, y)
end

# ╔═╡ 190a325e-9a6c-4613-ba0c-47f43b6b364d
md"## the TSP problem setup

_parameters_:
*  $n$: # of cities
*  $c_{ij}$: cost for travel from city $i$ to city $j$ (symmetric)

..._as a graph_:
*  node = city, edge = optimal route between two cities
*  complete; each pair of cities joined by edge b/c possible to travel
*  undirected; symmetric travel costs
*  weighted; edge $(i, j)$ labeled with cost to traverse, $c_{ij}$

_objective_: find the Hamiltonium circuit with the minimal total travel cost (sum along edges of circuit).

!!! note
	reminder of graph theory lingo:
	* _walk_: sequence of edges that join a sequence of vertices.
	* _trail_: walk in which all edges are distinct
	* _path_: walk in which all edges are distinct (thus a trail) _and_ all vertices are distinct
	* _circuit_: a trail in which the first and last vertices are the same
	* _cycle_ or _simple circuit_: circuit in which only the first and last vertices are the same (so otherwise no repeat vertices).
	* _Hamiltonian circuit_: a circuit that visits every vertex in the graph exactly once (edges could be repeated, but for TSP satisfying triangle inequality, I bet they won't...)

_decision variables_:
*  $x_{ij}$: 1 if edge $(i,j)$ included in the Hamiltonian circuit, 0 otherwise.

```math
\begin{align}
& \min \frac{1}{2} \sum_{i=1}^n\sum_{j=1}^n c_{ij} x_{ij}\\
& \text{s.t. } x_{ij} = x_{ji} , \;\; \forall (i,j) \in \{1, ..., n\}  \times \{1, ..., n\}\\ 
& \phantom{s.t. } x_{ij} \geq 0 , \;\; \forall (i,j) \in \{1, ..., n\}  \times \{1, ..., n\}\\ 
& \phantom{s.t. } x_{ii} = 0 , \;\; \forall i \in \{1, ..., n\}  \\ 
& \phantom{s.t. } \sum_{i=1} x_{ij} = 2 \\ 
\end{align}
```

the last constraint says exactly two edges involve each node (one incoming, the other outgoing, tho not explicitly tracked here.).

!!! warning
	subtour elimination constraints are missing. 

	e.g. the Dantzig, Fulkerson, Johnson subtour constraints are, for _every_ proper[^3] subset $S \subset \{1, ..., n\}$ of the $n$ cities:
	```math
	\begin{equation}
	\sum_{ i \in S } \sum_{ j \in S, \; j < i} x_{ij} < \lvert S \rvert
	\end{equation}
	```
	i.e. the number of edges present in the induced subgraph comprised of these nodes in $S$ is less than the size of the set. for a subtour, the number of edges in the nodes involved will be equal to the size of the set $S$. this constraint prevents that. 

	solvers like tight inequalities, so:
	```math
	\begin{equation}
	\sum_{ i \in S } \sum_{ j \in S, \; j < i} x_{ij} \leq \lvert S \rvert - 1
	\end{equation}
	```

	how many subtour elimination constraints are there?
	```math
	\begin{equation}
	\sum_{k=1}^{n-1} \binom{n}{k} = \sum_{k=0}^{n} \binom{n}{k}- \binom{n}{0} - \binom{n}{n} = 2^n-2
	\end{equation}
	```

!!! note \"idea: lazy subtour constraint enforcement\"
	we will implement subtour elimination constraints in a lazy fashion, i.e. only when we find a subtour constraint is violated in a solution we found, will we implement the subtour constraint to eliminate these subtours we see, then rerun. this _could_ be a cheaper alternative to specifying the $2^{n}-2$ subtour constraints. but not necessarily since we need to re-run the optimizer from scratch each time.

notes[^1][^2]

[^1]: the optimal circuit can be taken clockwise or counter-clockwise, both optimal b/c of symmetry.
[^2]: not necessary to specify which node is the depot. depot could be any; the optimal Hamiltonian circuit is the same.
[^3]: for the set of all $n$ cities, the number of edges _will_ be equal to the number of cities since it's a Hamiltonian circuit.

## linear programming (LP) approach
"

# ╔═╡ fcc5904a-73e6-404d-bca2-1888db9ba593
# construct the TSP model.
# note: subtour constraints not included.
# C: cost matrix for intercity travel
function build_tsp_model(C::Matrix{Float64})
	# get number of cities
	n = size(C)[1]
	
    model = Model(GLPK.Optimizer)
	# binary decision variables
	#           1, edge from i to j visited
	#   xᵢⱼ = 
	#           0, edge from i to j NOT visited
    @variable(model, x[1:n, 1:n], Bin, Symmetric) # binary, symmetric
	# objective (min costs = sum of costs on edges traveled)
    @objective(model, Min, sum(C .* x) / 2)
	# each city has one incoming, one outgoing edge (tho not explicitly so here).
    @constraint(model, [i in 1:n], sum(x[i, :]) == 2)
	# each city has no self-loops
    @constraint(model, [i in 1:n], x[i, i] == 0)
	# ❗ subtour constraints missing!
    return model
end;

# ╔═╡ 69f13766-a11e-4647-b5dc-bcf50a8cbb96
md"build TSP model, optimize, visualize"

# ╔═╡ 65dd77e1-06b0-4d3b-9a7b-875732ea713a
begin
	model = build_tsp_model(C)
	optimize!(model)
end

# ╔═╡ 9066c729-f905-43fe-a5a1-7ec28b3ec43b
soln = value(model[:x]) # the decision variables in the solution

# ╔═╡ a4d5f508-ccf9-41fe-be49-64be17a02b95
function viz_soln(soln, x, y)
	fig = Figure()
	ax = Axis(fig[1, 1])
	hidedecorations!(ax)
	hidespines!(ax)
	# draw paths taken
	n = length(x)
	for i = 1:n
		text!(x[i]+0.55, y[i]+0.55, text="$i")
		for j = i+1:n
			if soln[i, j] > 0.5
				lines!([x[i], x[j]], [y[i], y[j]], color="black")
			end
		end
	end
	scatter!(x, y, color="green", markersize=25)
	fig
end;

# ╔═╡ b98854f5-ab29-4b27-af3b-20644ab1c592
viz_soln(soln, x, y)

# ╔═╡ 3f0b6ed8-1d8e-4f64-b812-dedb6d563b55
md"❗ yikes, subtours for sure. let's find the smallest subtour, then add the constraint to break that subtour.

... first, convert the solution (in terms of decision variables in a matrix) into a graph.
"

# ╔═╡ ce02dae0-0b1f-48a6-95eb-3653b4d95102
function soln_to_graph(soln)
	g = SimpleGraph(soln .> 0.5)
end;

# ╔═╡ 626d8b75-ec18-4194-9e20-b50e8d76c11e
g = soln_to_graph(soln)

# ╔═╡ 31048010-987c-46ee-8dfe-06a9c472e108
md"...second, find the smallest subtour in the current solution."

# ╔═╡ d4e80e18-7157-46a8-8683-21675edff021
# return list of nodes comprising the smallest cycle in the graph (subtour)
function find_smallest_subtour(g::SimpleGraph)
	n = nv(g)
	unvisited_nodes = Set(1:n)
	shortest_cycle = [i for i = 1:n] # assume solution feasible to start.
	while ! isempty(unvisited_nodes)
		# find a cycle.
		this_cycle = []
		my_neighbors = deepcopy(unvisited_nodes) # well... to enter while loop and initiate
		while ! isempty(my_neighbors)
			# grab a neighbor (first, will be unvisited node)
			current_node = pop!(my_neighbors)
			# walk to there. this is part of cycle.
			push!(this_cycle, current_node)
			# we visisted this node...
			pop!(unvisited_nodes, current_node)
			# for next step, re-make neighbor list
			my_neighbors = filter(i->i∈unvisited_nodes, neighbors(g, current_node))
		end
		# uncomment if u wanna see all cycles :)
		# @show this_cycle
		if length(this_cycle) < length(shortest_cycle)
			shortest_cycle = this_cycle
		end
	end
	return shortest_cycle
end;

# ╔═╡ fb07eece-eef5-4327-834d-d20efc1e657c
smallest_subtour = find_smallest_subtour(g)

# ╔═╡ fb9e005b-a3a8-4c06-a505-547a5e6bd3c1
[(i, j) for (i, j) in Iterators.product(smallest_subtour, smallest_subtour) if i < j]

# ╔═╡ 50ce17e3-b9a3-4b7a-bcac-ec4dc3177fd3
md"...third, rebuild TSP model, but add a constraint to break this subtour!" 

# ╔═╡ ec9ec20e-4cd3-4271-b37f-be840e4ead44
function iterative_tsp(C::Matrix{Float64})
	n = size(C)[1]
	
	model = build_tsp_model(C)
	optimize!(model)
	
	soln = value(model[:x])
	
	g = soln_to_graph(soln)

	smallest_subtour = find_smallest_subtour(g)

	while length(smallest_subtour) < n
		@info "found subtour :("
		# add subtour constraint to break smallest subtour
		# build set of nodes S comprising this subtour.
		S = [(i, j) for (i, j) in Iterators.product(smallest_subtour, smallest_subtour) if i < j]
		@constraint(
			model,
			sum(model[:x][i, j] for (i, j) in S) <= length(smallest_subtour) - 1,
		)
		optimize!(model)
		
		soln = value(model[:x])
		g = soln_to_graph(soln)
		smallest_subtour = find_smallest_subtour(g)
	end
	return soln
end

# ╔═╡ 0610083f-4eb6-489c-bf50-fb45e66190e2
actual_soln = iterative_tsp(C)

# ╔═╡ 40b19880-7bf6-4e72-a8fb-ef320698ec09
viz_soln(actual_soln, x, y)

# ╔═╡ 50504e4a-d41c-4e37-a319-2b2e31c7b846
md"## dynamic programming (DP) approach

> dynamic programming is a very powerful algorithmic paradigm in which a problem is solved by identifying a collection of subproblems and tackling them one by one, smallest first, using the answers to small problems to help figure out larger ones, until the whole lot of them is solved. - Dasgupta, Papadimitriou, Vazirani

💡 break TSP into smaller subproblems involving fewer nodes. (Bellman–Held–Karp algorithm)

let $L(S, j)$ be the length of the shortest path that (i) starts at node 1 (the warehouse), (ii) visits every [customer] node in $i \in S \subseteq \{2, ..., n\}$, and (iii) ends at $j \in S$.

> finding the right subproblem takes creativity and experimentation. - Dasgupta, Papadimitriou, Vazirani

!!! note
	_path_ := sequence of edges joining sequential vertices such that all vertices involved are distinct.

the solution to the TSP (minimal cost of a Hamiltonian circuit) is then 
```math
\min_{j \in \{2, ..., n\}} [L(\{2, ..., n\}, j) + c_{j1}]
```
since we take shortest path from [warehouse] node 1 to last city $j$, then go back to warehouse node $1$; but, we must find the last city $j$ that gives the minimal-distance tour, which is shortest distance from 1 to $j$ plus distance from $j$ to 1 to complete the tour (hence, the $\min$).

the relationship between subproblems is as follows. 
the shortest path from warehouse node $1$ to last-city $j\in S$ passing thru all nodes in $S$ must be the shortest path going from $1$ to a second-to-last city $i\in S\setminus \{j\}$, then from the second-to-last city $i$ to last-city $j$, for some second-to-last city $i$---and, we choose the second-to-last city $i$ that gives the minimal overall path length from $1$ to $j$.

```math
\begin{equation}
	L(S, j) = \min_{i \in S\setminus \{j\}} [L(S \setminus \{j\}, i)+c_{ij}]
\end{equation}
```

we start with sets $S \subset \{2, ..., n\}$ of size $\lvert S \rvert =1$ then work our way up to progressively larger sets that use the solutions to the subproblems with the smaller sets.

### generate (smaller) TSP problem
"

# ╔═╡ 59476693-7478-44b4-8d82-97608f437066
begin
	# generate new (smaller) problem
	n′ = 10                       # number of cities
	x′, y′ = generate_towns(n′)   # locations of cities
	C′ = distance_matrix(x′, y′)  # pairwise distance matrix
	viz_setup(x′, y′)             # visualize
end

# ╔═╡ 98e1b106-00ae-4ed2-b7f2-b42f813e67c2
md"### solve via brute force"

# ╔═╡ 500560eb-229d-4d51-858d-0070fbc578cc
all_hcircuits = [vcat([1], p, [1]) for p in permutations(2:n′, n′-1)]

# ╔═╡ d9b23baf-1b3b-4df9-8090-bdfc5cc285c2
begin
	# loop thru permutations, compute cost of all tours to find optimal
	tour_costs = zeros(length(all_hcircuits)) # store costs here
	for (i, tour) in enumerate(all_hcircuits)
		for k = 1:length(tour) - 1
			tour_costs[i] += C′[tour[k], tour[k+1]]
		end
	end
	id_opt_tour = argmin(tour_costs)
	minimum(tour_costs), all_hcircuits[id_opt_tour]
end

# ╔═╡ dc25d25b-d4db-45b8-a95c-4fc7872dc4e7
md"### building the DP table

we store $L(S, j)$ in a dictionary.
"

# ╔═╡ 6505861e-8963-450b-a61f-1b456a2172c8
L = Dict() # inefficient but conceptual

# ╔═╡ 591a64ed-4ecb-449d-8ed3-a3d9dd75d0d8
md"_base case_: for $\lvert S\rvert = 1$, $L(S, j)$ is the minimal path distance when hoping from warehouse node 1 to customer $j$. easy since there is just one path to do this. so $L(S, j)=c_{1j}$ for $\lvert S\rvert = 1$.
"

# ╔═╡ 4029d062-d637-4942-b51f-e3b9b5c253d2
for j = 1:n′
	L[Set(j)] = Dict()
	L[Set(j)][j] = C′[1, j]
end

# ╔═╡ 6181fcd2-39b6-4d3c-b6a1-02f341a89fe1
md"...now work our way up to larger problems"

# ╔═╡ 54e87371-3799-4487-899b-a8b7b061cb1a
# loop over set S ⊆ {2, ..., n′} sizes s := |S|
# node s=1 not included b/c we handed it in the base case.
# at most |S|=n′-1 since node 1 (warehouse) not included in S.
for s = 2:n′-1
	# loop over all ⊆ S {2, ..., n} such that |S| = s
	for S in Set.(combinations(2:n′, s))
		L[S] = Dict()
		# loop over all customers in S that we could end at.
		for j ∈ S
			# L[S][j] = L(S, j)
			#   = min travel cost from 1 to j ∈ S passing thru all nodes in S
			S_minus_j = setdiff(S, j) # candidate second-to-list cities
			min_travel_cost = Inf
			# loop over second-to-last cities i
			for i ∈ S_minus_j
				# can get this from previous round
				travel_cost = L[S_minus_j][i] + C′[i, j]
				if travel_cost < min_travel_cost
					min_travel_cost = travel_cost
				end
			end
			L[S][j] = min_travel_cost
		end
	end
end

# ╔═╡ 62fe7322-f279-499a-ba5d-7ae3c1c7a6d1
L

# ╔═╡ 15cef738-eb1d-4f15-87f6-3e202c9fe227
md"### analyze DP table
first, what is the min cost of a Hamiltonian circuit?
"

# ╔═╡ bf799a95-d010-4c4f-a6e7-5e597b9e81a9
begin
    min_cost_hcircuit = Inf
	# loop over all possible last cities in the tour
	opt_last_city = 0
	for j = 2:n′
		# cost of Hamiltonian circuit with this as the last city
		hcircuit_cost = L[Set(2:n′)][j] + C′[j, 1]
		if hcircuit_cost < min_cost_hcircuit
			min_cost_hcircuit = hcircuit_cost
			opt_last_city = j
		end
	end
	min_cost_hcircuit, opt_last_city
end

# ╔═╡ 3d5d888b-150d-4014-b084-e1932cd9e411
begin
	# assert we match the brute-force solution (order irrelevant)
	@assert all_hcircuits[id_opt_tour][end-1] == opt_last_city || all_hcircuits[id_opt_tour][2] == opt_last_city
	@assert min_cost_hcircuit ≈ minimum(tour_costs)
end

# ╔═╡ 459daf1d-2547-4c9d-87fc-0b3e3454431a
md"what is the sequence of cities to visit? to get precise cities to travel, work backwards. e.g. from above we get the last city to visit."

# ╔═╡ 99b5aa5e-6dfa-4a4e-9611-44ffe2f26fb4
begin
	hcircuit = [1 for i = 1:n′+1] # store hircuit here.
	# start with all candidate customers. 
	# we will prune this as we determine the h-circuit
	S = Set(2:n′)
	# loop over cities in the tour, backwards.
	for c = n′:-1:2
		# loop over last-cities in this subproblem
		min_path_cost = Inf
		i_opt = 0
		for i ∈ S
			# cost to start at 1, hit all nodes in S, end at i, go to next city
			path_cost = L[S][i] + C′[i, hcircuit[c+1]]
			if path_cost < min_path_cost
				min_path_cost = path_cost
				i_opt = i
			end
		end
		hcircuit[c] = i_opt
		S = setdiff(S, i_opt)
	end
	hcircuit
end

# ╔═╡ 57b0d2bf-e621-4544-b0da-640634d4b1b1
# assert it matches the brute-force solution
@assert hcircuit == all_hcircuits[id_opt_tour] || reverse(hcircuit) == all_hcircuits[id_opt_tour]

# ╔═╡ ae83335c-44eb-4901-825b-086d31732ba7
begin
	# to viz, put in same form as LP solution
	soln′ = zeros(n′, n′)
	for t = 1:n′
		soln′[hcircuit[t], hcircuit[t+1]] = soln′[hcircuit[t+1], hcircuit[t]] = 1
	end
	viz_soln(soln′, x′, y′)
end

# ╔═╡ 3020a402-105f-4675-803b-550b8417eb90
md"## local search (2-opt)

based on DP example
"

# ╔═╡ cd4fc1f6-ea70-474a-98d5-a6fdbc966f3c
function viz_route(route::Vector{Int}, x, y)
	fig = Figure()
	ax = Axis(fig[1, 1])
	hidedecorations!(ax)
	hidespines!(ax)
	n = length(x)
	for i = 1:n
		text!(x[i]+0.55, y[i]+0.55, text="$i")
	end
	# draw path taken
	for i = 1:length(route)-1
		u = route[i]
		v = route[i+1]
		lines!([x[u], x[v]],
			   [y[u], y[v]], 
			color="black"
		)
	end
	scatter!(x, y, color="green", markersize=25)
	fig
end;

# ╔═╡ 90fc3a13-1742-431c-9e0d-e1a8bc56a640
a_random_route = vcat([1], shuffle(2:n′), [1])

# ╔═╡ 52aea663-9b95-40d6-a08b-0942a01bdae4
viz_route(a_random_route, x′, y′)

# ╔═╡ e43f883f-4f85-4a95-ab37-eed40d6548d7
# include start and end...
function route_cost(route::Vector{Int}, C::Matrix{Float64})
	if length(route) == 1
		return 0.0
	else
		return sum(C[route[i], route[i+1]] for i = 1:length(route) - 1)
	end
end

# ╔═╡ 1d49eb47-11c7-473f-995b-1e19f7ac8896
route_cost(a_random_route, C′)

# ╔═╡ 86e43c31-6987-41f1-8562-fed5058cdcf6
min_cost_hcircuit # smaller

# ╔═╡ ff0a8a0f-d949-4aa7-84b4-570f7331b184
function two_opt_route(route::Vector{Int}, C::Matrix{Float64})
	opt_distance = route_cost(route, C)
	found_improvement = true
	while found_improvement
		found_improvement = false
		# end node cannot be swapped
		for i = 1:length(route)-2
			for j = i+1:length(route)-1
				new_route = vcat(route[1:i], reverse(route[i+1:j]), route[j+1:end])
				this_route_cost = route_cost(new_route, C)
				if this_route_cost < opt_distance
					found_improvement = true
					opt_distance = this_route_cost
					route = new_route
				end
			end
		end
	end
	return route
end

# ╔═╡ a060d771-5370-4fcc-af3f-635122a72606
locally_optimized_route = two_opt_route(a_random_route, C′)

# ╔═╡ 43005a6e-9128-413c-a8fa-294f19f96b75
viz_route(locally_optimized_route, x′, y′)

# ╔═╡ 0a6d0c23-c9f1-40c3-8aff-cbada442174e
@assert locally_optimized_route == hcircuit || locally_optimized_route == reverse(hcircuit) # well, this doesn't have to be true

# ╔═╡ Cell order:
# ╠═537ca880-870b-4626-a38b-c1c33a71d8c1
# ╠═5f9ea40e-5c04-451f-8552-a06fc3532986
# ╟─c95b7265-6d0b-4b1a-8db8-2f232bd0a64d
# ╠═f4352476-0820-4603-b8b9-2219a54f0e87
# ╠═622fe6ed-707a-4c88-a791-d11c031d2d37
# ╟─c1c58fc8-949f-4a02-b2f0-e8c3531e6517
# ╠═bf2588f6-1b6d-11ee-3729-c3d23f30a765
# ╠═85e5731c-0050-4fcf-b229-3d26891ea3e7
# ╟─b8df9338-e8a1-4c09-81b4-efbc7d078f30
# ╠═00904c71-51b7-4d57-ae51-b6f925fc3a6a
# ╟─190a325e-9a6c-4613-ba0c-47f43b6b364d
# ╠═fcc5904a-73e6-404d-bca2-1888db9ba593
# ╟─69f13766-a11e-4647-b5dc-bcf50a8cbb96
# ╠═65dd77e1-06b0-4d3b-9a7b-875732ea713a
# ╠═9066c729-f905-43fe-a5a1-7ec28b3ec43b
# ╠═a4d5f508-ccf9-41fe-be49-64be17a02b95
# ╠═b98854f5-ab29-4b27-af3b-20644ab1c592
# ╟─3f0b6ed8-1d8e-4f64-b812-dedb6d563b55
# ╠═ce02dae0-0b1f-48a6-95eb-3653b4d95102
# ╠═626d8b75-ec18-4194-9e20-b50e8d76c11e
# ╟─31048010-987c-46ee-8dfe-06a9c472e108
# ╠═d4e80e18-7157-46a8-8683-21675edff021
# ╠═fb07eece-eef5-4327-834d-d20efc1e657c
# ╠═fb9e005b-a3a8-4c06-a505-547a5e6bd3c1
# ╟─50ce17e3-b9a3-4b7a-bcac-ec4dc3177fd3
# ╠═ec9ec20e-4cd3-4271-b37f-be840e4ead44
# ╠═0610083f-4eb6-489c-bf50-fb45e66190e2
# ╠═40b19880-7bf6-4e72-a8fb-ef320698ec09
# ╟─50504e4a-d41c-4e37-a319-2b2e31c7b846
# ╠═59476693-7478-44b4-8d82-97608f437066
# ╟─98e1b106-00ae-4ed2-b7f2-b42f813e67c2
# ╠═500560eb-229d-4d51-858d-0070fbc578cc
# ╠═d9b23baf-1b3b-4df9-8090-bdfc5cc285c2
# ╟─dc25d25b-d4db-45b8-a95c-4fc7872dc4e7
# ╠═6505861e-8963-450b-a61f-1b456a2172c8
# ╟─591a64ed-4ecb-449d-8ed3-a3d9dd75d0d8
# ╠═4029d062-d637-4942-b51f-e3b9b5c253d2
# ╟─6181fcd2-39b6-4d3c-b6a1-02f341a89fe1
# ╠═54e87371-3799-4487-899b-a8b7b061cb1a
# ╠═62fe7322-f279-499a-ba5d-7ae3c1c7a6d1
# ╟─15cef738-eb1d-4f15-87f6-3e202c9fe227
# ╠═bf799a95-d010-4c4f-a6e7-5e597b9e81a9
# ╠═3d5d888b-150d-4014-b084-e1932cd9e411
# ╟─459daf1d-2547-4c9d-87fc-0b3e3454431a
# ╠═99b5aa5e-6dfa-4a4e-9611-44ffe2f26fb4
# ╠═57b0d2bf-e621-4544-b0da-640634d4b1b1
# ╠═ae83335c-44eb-4901-825b-086d31732ba7
# ╟─3020a402-105f-4675-803b-550b8417eb90
# ╠═cd4fc1f6-ea70-474a-98d5-a6fdbc966f3c
# ╠═90fc3a13-1742-431c-9e0d-e1a8bc56a640
# ╠═52aea663-9b95-40d6-a08b-0942a01bdae4
# ╠═e43f883f-4f85-4a95-ab37-eed40d6548d7
# ╠═1d49eb47-11c7-473f-995b-1e19f7ac8896
# ╠═86e43c31-6987-41f1-8562-fed5058cdcf6
# ╠═ff0a8a0f-d949-4aa7-84b4-570f7331b184
# ╠═a060d771-5370-4fcc-af3f-635122a72606
# ╠═43005a6e-9128-413c-a8fa-294f19f96b75
# ╠═0a6d0c23-c9f1-40c3-8aff-cbada442174e
