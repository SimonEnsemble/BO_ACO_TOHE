### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ af90a910-2708-11ee-1269-3b18c2322a80
begin
	import Pkg; Pkg.activate()
	using JuMP
	import GLPK
	import Random
	using CairoMakie, Graphs, Combinatorics, PlutoUI, LinearAlgebra, Random
end

# ╔═╡ f38a15a1-d348-4dbc-b4d1-a3e8ef4277f0
TableOfContents()

# ╔═╡ 037e6941-fcc5-4fe5-90ec-778d4eb6bb64
shuffle

# ╔═╡ 02e0561b-2fbb-4fd6-8cdc-3f270812240d
md"# the orienteering problem (OP)

see:
> Gunawana et al. Orienteering Problem: A survey of recent variants, solution approaches and applications. (2016)

_params_:
* graph $G=(\mathcal{N}, \mathcal{E})$
  * nodes $\mathcal{N}=\{1, ..., N\}$
    * each node $i$ has score $s_i \geq 0$.
  *  $t_{ij}$: travel time across edge $(n_i, n_j) \in \mathcal{E}$ joining nodes $n_i$ and $n_j$
* single robot
  * travel budget $T_{max}$ due to battery/fuel limit
  * starts, ends at node $1$

_decision variables_
*  $x_{ij} \in \{0, 1\}$: indicator for path of robot traversing edge $(n_i, n_j) \in \mathcal{E}$, _from_ node $i$ _to_ node $j$. 
*  $2 \leq u_i \leq N$: dummy variable, for subtour elimination constraints, that indicates order in which nodes are visited. $u_i < u_j$ implies node $i$ visited before node $j$.

_objective_: choose robot path to maximize rewards collected along that path.
note, $\sum_{j=2}^n x_{ij}$ counts the number of visits to node $i$. don't get reward on starting node $1$.

```math
\max \sum_{i=2}^n s_i \sum_{j=2}^n x_{ij}
```

_constraints_:
* we leave node 1 and enter node 1 once.
```math
\sum_{j=2}^N x_{1j} = \sum_{i=2}^N x_{i1} = 1
```
* budget of robot
```math
\sum_{i=1}^N \sum_{j=1}^N t_{ij} x_{ij} \leq T_{max}
```
* path is connected. each node visisted at most once.
```math
\sum_{j=1}^N x_{kj} = \sum_{i=1}^N x_{ik} \leq 1 \text{ for } k \in \{2,..., N\}
```
* subtour elimination
```math
u_i - u_j + 1 \leq (n-1)(1-x_{ij}) \text{ for } (i, j) \in \{2,..., N\} \times \{2,..., N\}
```

## data (problem creation)
"

# ╔═╡ 2a799822-e7fc-4c26-8a2e-21c73858a924
struct OP
	n::Int
	x::Vector{Float64}
	y::Vector{Float64}
	r::Vector{Float64}
	t::Matrix{Float64}
	T_max::Float64
end

# ╔═╡ 0a1887e1-c445-4585-a2a6-765d73cd9f7e
function generate_op(n::Int, T_max::Float64; random_seed::Int=1337)
	rng = Random.MersenneTwister(random_seed)
	# positions
    x = 100 * rand(rng, n)
    y = 100 * rand(rng, n)
	
	# rewards
	r = randn(rng, n) .^ 2
	# r .-= minimum(r)
	r[1] = 0.0
	
	# costs
	t = [sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2) for i in 1:n, j in 1:n]
	return OP(n, x, y, r, t, T_max)
end

# ╔═╡ ae26af02-e9b3-41ff-ba2d-83ef2ccf3d87
op = generate_op(25, 150.0, random_seed=1338)

# ╔═╡ ff88f5b6-914a-4966-b9c4-cd012f62e0ad
function viz_setup(op::OP)
	fig = Figure()
	ax = Axis(fig[1, 1])
	scatter!(op.x[2:end], op.y[2:end], color=op.r[2:end], markersize=25)
	scatter!([op.x[1]], [op.y[1]], color="white", strokecolor="red", strokewidth=4, markersize=25)
	for i = 1:op.n
		text!(op.x[i]+1, op.y[i]+1, text="$i")
	end
	# hidedecorations!(ax)
	# hidespines!(ax)
	Colorbar(fig[1, 2], label="reward")
	fig
end

# ╔═╡ 0829b504-ae25-4b59-ad6c-988fad187431
viz_setup(op)

# ╔═╡ f709d274-5b68-417f-9ae8-e6de9358f9fc
md"## LP model of the OP"

# ╔═╡ f19a2e41-b4a2-48c5-8192-6f15f893770f
function build_op_model(op::OP; subtour_elimin_constraints=false)
	n = op.n
	
	model = Model(GLPK.Optimizer)
	# binary decision variables
	#           1, edge from i to j visited
	#   xᵢⱼ = 
	#           0, edge from i to j NOT visited
	@variable(model, x[1:n, 1:n], Bin) # binary
	# objective (max rewards)
	@objective(model, Max, sum(op.r[i] * sum(x[i, j] for j = 2:n) for i = 2:n))
	# no self-loops
	@constraint(model, [i in 1:n], x[i, i] == 0)
	# node i has one incoming, one outgoing edge.
	@constraint(model, sum(x[1, :]) == 1)
	@constraint(model, sum(x[:, 1]) == 1)
	# nb incoming edges = number of outgoing edges (path connected)
	@constraint(model, [i in 2:n], sum(x[i, :]) == sum(x[:, i]))
	# node visisted zero or one times
	@constraint(model, [i in 2:n], sum(x[i, :]) ≤ 1)
	# budget constraint
	@constraint(model, sum(op.t .* x) ≤ op.T_max)
	# subtour elimination. slow AF...
	if subtour_elimin_constraints
		@variable(model, u[2:n], Int)
		@constraint(model, [i in 2:n], 2 ≤ u[i]) 
		@constraint(model, [i in 2:n], u[i] ≤ n)
		for i = 2:n
			for j = 2:n
				@constraint(model, u[i] - u[j] + 1 ≤ (n - 1) * (1 - x[i, j]))
			end
		end
	end
	return model
	# ❗ subtour constraints missing!
end

# ╔═╡ 3095d396-6654-490b-8e63-a9514e2e9526
md"## optimization"

# ╔═╡ 4863d877-bf2f-430a-be10-04a6d179783e
subtour_elimin_constraints = false

# ╔═╡ b92eaa56-e8e8-4ef6-9d76-4a9c15ed7568
model = build_op_model(op, subtour_elimin_constraints=subtour_elimin_constraints)

# ╔═╡ c4fccd2a-686d-4fb4-986f-b33b66be2eb7
optimize!(model)

# ╔═╡ ea42fb00-54c9-4ef3-959e-10aa56d0c463
solution_summary(model)

# ╔═╡ de2b07da-32d2-4a01-b347-0da451674acf
op.T_max

# ╔═╡ 8d679a8d-1202-4251-aee8-69781e17f4ef
T_used = sum(op.t .* value.(model[:x]))

# ╔═╡ 8686904b-2079-4f70-badd-da1edee1226e
function viz_soln(op::OP, model)
	fig = Figure()
	ax = Axis(fig[1, 1])
	scatter!(op.x[2:end], op.y[2:end], color=op.r[2:end], markersize=25)
	scatter!([op.x[1]], [op.y[1]], color="white", 
		strokecolor="red", strokewidth=4, markersize=25)
	for i = 1:op.n
		text!(op.x[i]+1, op.y[i]+1, text="$i")
	end
	for i = 1:op.n
		for j = 1:op.n
			if value.(model[:x])[i, j] > 0.5
				lines!([op.x[i], op.x[j]], [op.y[i], op.y[j]], color="black")
			end
		end
	end
	# hidedecorations!(ax)
	# hidespines!(ax)
	Colorbar(fig[1, 2], label="reward")
	fig
end

# ╔═╡ bd5b6c16-74a0-49dd-9e87-45da40bfc56e
viz_soln(op, model)

# ╔═╡ 397d61c4-8508-49aa-baf0-5629e8a6bbcd
md"## lazy subtour elimination constraints"

# ╔═╡ 30ef2748-dfd6-42d3-9bb7-40a822898dd0
g = SimpleDiGraph(value.(model[:x]) .> 0.5)

# ╔═╡ 6c932ac6-6258-4171-81af-bf840cbfe382
cycles_without_node_1 = filter(c -> !(1 in c), simplecycles(g))

# ╔═╡ 6c623883-d0f0-444a-8475-14ada8ef22a6
function iterative_op(op::OP)
	model = build_op_model(op)
	optimize!(model)
	
	g = SimpleDiGraph(value.(model[:x]) .> 0.5)

	cycles_without_node_1 = filter(c -> !(1 in c), simplecycles(g))
	while length(cycles_without_node_1) > 0
		@info "breaking cycle"
		# add constraints to break cycles
		for c in cycles_without_node_1
			S = [(i, j) for (i, j) in Iterators.product(c, c)]
			@constraint(
				model,
				sum(model[:x][i, j] for (i, j) in S) <= length(c) - 1,
			)
		end
	
		optimize!(model)
		g = SimpleDiGraph(value.(model[:x]) .> 0.5)
		cycles_without_node_1 = filter(c -> !(1 in c), simplecycles(g))
	end
	return model
end

# ╔═╡ 71c3b084-2b3b-4b62-95c7-d532cdbebc8c
model_it = iterative_op(op)

# ╔═╡ 08d6d81e-61d6-48e4-bdce-61e38114c8e5
viz_soln(op, model_it)

# ╔═╡ 8e733065-9a3c-4534-8eb5-9171569b57e8
md"## 2-opt of a proposed route"

# ╔═╡ dd6506de-a09e-4dc8-b428-d8f1c15069a0
function viz_route(op::OP, route::Vector{Int})
	fig = Figure()
	ax = Axis(fig[1, 1])
	scatter!(op.x[2:end], op.y[2:end], color=op.r[2:end], markersize=25)
	scatter!([op.x[1]], [op.y[1]], color="white", 
		strokecolor="red", strokewidth=4, markersize=25)
	for i = 1:op.n
		text!(op.x[i]+1, op.y[i]+1, text="$i")
	end
	for i = 1:length(route)-1
		lines!([op.x[route[i]], op.x[route[i+1]]], 
			   [op.y[route[i]], op.y[route[i+1]]], color="black")
	end
	# hidedecorations!(ax)
	# hidespines!(ax)
	Colorbar(fig[1, 2], label="reward")
	fig
end

# ╔═╡ 840d3577-0c6c-4bba-b9df-c6e6c4803c01
a_random_route = vcat([1], shuffle(2:op.n-2), [1])

# ╔═╡ 090e54da-9a1d-4a11-9ddf-ddc65c2bcf4a
viz_route(op, a_random_route)

# ╔═╡ 893a315f-106f-44cf-afca-eec889097603
begin
	# include start and end...
	function route_cost(route::Vector{Int}, op::OP)
		return sum(op.t[route[i], route[i+1]] for i = 1:length(route) - 1)
	end
	
	@assert route_cost([1, 2], op) == op.t[1, 2]
	@assert route_cost([1, 2, 4], op) == op.t[1, 2] + op.t[2, 4]
end

# ╔═╡ 432adf65-602f-4b4b-922f-dbb3a8bc5624
function two_opt_route!(route::Vector{Int}, op::OP)
	opt_distance = route_cost(route, op)
	found_improvement = true
	while found_improvement
		found_improvement = false
		# end node cannot be swapped
		for i = 1:length(route)-2
			for j = i+1:length(route)-1
				new_route = vcat(route[1:i], reverse(route[i+1:j]), route[j+1:end])
				this_route_cost = route_cost(new_route, op)
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

# ╔═╡ 26efd5c3-1030-4313-aec1-471bd50c91ae
local_opt_route = two_opt_route!(a_random_route, op)

# ╔═╡ d674f11f-080a-4fe2-a0ab-cd1e13700d50
a_random_route

# ╔═╡ f7b20237-25e6-4f4f-b806-6065d9f0040b
viz_route(op, local_opt_route)

# ╔═╡ d338bbc6-61f5-44fd-b42e-f3b5170f348e
md"## ant colony optimization"

# ╔═╡ f926b1a0-d9e5-4386-897a-72be5458dd58
op

# ╔═╡ 6bb61d9f-ef27-4b1f-9106-78c34765aac1
# heuristic for appeal of traveling i -> j
function η(i, j)
	return op.r[j] / op.t[i, j]
end

# ╔═╡ 69cbfd3d-0d98-4dd7-a2b4-b9768ee40b6a
op

# ╔═╡ 7c537482-7a41-447f-bd5f-5bebbe935ae1
function candidates_for_next_node(partial_route::Array{Int}, op::OP)
	cost_so_far = route_cost(partial_route, op)
end

# ╔═╡ Cell order:
# ╠═af90a910-2708-11ee-1269-3b18c2322a80
# ╠═f38a15a1-d348-4dbc-b4d1-a3e8ef4277f0
# ╠═037e6941-fcc5-4fe5-90ec-778d4eb6bb64
# ╟─02e0561b-2fbb-4fd6-8cdc-3f270812240d
# ╠═2a799822-e7fc-4c26-8a2e-21c73858a924
# ╠═0a1887e1-c445-4585-a2a6-765d73cd9f7e
# ╠═ae26af02-e9b3-41ff-ba2d-83ef2ccf3d87
# ╠═ff88f5b6-914a-4966-b9c4-cd012f62e0ad
# ╠═0829b504-ae25-4b59-ad6c-988fad187431
# ╟─f709d274-5b68-417f-9ae8-e6de9358f9fc
# ╠═f19a2e41-b4a2-48c5-8192-6f15f893770f
# ╟─3095d396-6654-490b-8e63-a9514e2e9526
# ╠═4863d877-bf2f-430a-be10-04a6d179783e
# ╠═b92eaa56-e8e8-4ef6-9d76-4a9c15ed7568
# ╠═c4fccd2a-686d-4fb4-986f-b33b66be2eb7
# ╠═ea42fb00-54c9-4ef3-959e-10aa56d0c463
# ╠═de2b07da-32d2-4a01-b347-0da451674acf
# ╠═8d679a8d-1202-4251-aee8-69781e17f4ef
# ╠═8686904b-2079-4f70-badd-da1edee1226e
# ╠═bd5b6c16-74a0-49dd-9e87-45da40bfc56e
# ╟─397d61c4-8508-49aa-baf0-5629e8a6bbcd
# ╠═30ef2748-dfd6-42d3-9bb7-40a822898dd0
# ╠═6c932ac6-6258-4171-81af-bf840cbfe382
# ╠═6c623883-d0f0-444a-8475-14ada8ef22a6
# ╠═71c3b084-2b3b-4b62-95c7-d532cdbebc8c
# ╠═08d6d81e-61d6-48e4-bdce-61e38114c8e5
# ╟─8e733065-9a3c-4534-8eb5-9171569b57e8
# ╠═dd6506de-a09e-4dc8-b428-d8f1c15069a0
# ╠═840d3577-0c6c-4bba-b9df-c6e6c4803c01
# ╠═090e54da-9a1d-4a11-9ddf-ddc65c2bcf4a
# ╠═893a315f-106f-44cf-afca-eec889097603
# ╠═432adf65-602f-4b4b-922f-dbb3a8bc5624
# ╠═26efd5c3-1030-4313-aec1-471bd50c91ae
# ╠═d674f11f-080a-4fe2-a0ab-cd1e13700d50
# ╠═f7b20237-25e6-4f4f-b806-6065d9f0040b
# ╟─d338bbc6-61f5-44fd-b42e-f3b5170f348e
# ╠═f926b1a0-d9e5-4386-897a-72be5458dd58
# ╠═6bb61d9f-ef27-4b1f-9106-78c34765aac1
# ╠═69cbfd3d-0d98-4dd7-a2b4-b9768ee40b6a
# ╠═7c537482-7a41-447f-bd5f-5bebbe935ae1
