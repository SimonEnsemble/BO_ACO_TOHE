### A Pluto.jl notebook ###
# v0.20.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ d493a41c-3879-11ee-32aa-052ae56d5240
begin
	import Pkg; Pkg.activate(joinpath("..", "aco"))
	push!(LOAD_PATH, joinpath("..", "src"))

	using Revise, MOACOTOP, Graphs, MetaGraphs, Random, Test, CairoMakie, ColorSchemes, PlutoUI, Distributions

	import AlgebraOfGraphics: set_aog_theme!, firasans
	set_aog_theme!(fonts=[firasans("Light"), firasans("Light")])
	the_resolution = (500, 380)
	update_theme!(
		fontsize=20, 
		linewidth=2,
		markersize=14,
		titlefont=firasans("Light"),
		# resolution=the_resolution
	)
end

# ╔═╡ 2d6e9814-74e5-4e07-9980-b3f6c06863e9
md"# testing

## a test instance
test with a manually-constructed TOP.

edges are either low- or high-risk.

nodes are either high- or low-reward.

"

# ╔═╡ 305a8d3c-98c8-4ca2-baa8-24cbd1f74178
begin
	# risks
	ω =  Dict("lo" => 0.8, "hi" => 0.2)
	
	# rewards
	r = Dict("hi" => 15.0, "lo" => 10.0)
end

# ╔═╡ 10219d1e-6927-4618-8f02-bb08721587e0
function generate_manual_top(ω, r)
	g = MetaDiGraph(SimpleGraph(11))
	# add edges
	edge_list = [
		# branch
		(1, 9, ω["lo"]),
		# branch
		(1, 10, ω["hi"]),
		(10, 11, ω["hi"]),
		# cycle
		(1, 8, ω["lo"]),
		(8, 7, ω["lo"]),
		(7, 6, ω["hi"]),
		(6, 4, ω["hi"]),
		(4, 3, ω["hi"]),
		(3, 2, ω["lo"]),
		(2, 1, ω["lo"]),
		# bridge off cycle
		(4, 5, 1.0),
		# shortcut in cycle
		(7, 3, ω["lo"]),
	]
	for (i, j, ω) in edge_list
		add_edge!(g, i, j, :ω, ω)
		add_edge!(g, j, i, :ω, ω)
	end
	# assign nodes rewards
	rewards = Dict(
		1  => r["lo"], 
		10 => r["hi"], 
		11 => r["hi"], 
		9  => r["lo"], 
		2  => r["hi"], 
		3  => r["lo"], 
		7  => r["lo"], 
		8  => r["lo"], 
		6  => r["lo"], 
		4  => r["hi"], 
		5  => r["hi"]
	)

	for v = 1:nv(g)
		set_prop!(g, v, :r, rewards[v])
	end
	
	return TOP(nv(g), g, 2)
end

# ╔═╡ 5bbbfd5c-d28e-4dcb-85c7-892599f49ca5
TOP

# ╔═╡ d1349d2b-4956-4d42-a93f-7f666f2444d2
top = generate_manual_top(ω, r)

# ╔═╡ 24531d6e-18c1-452d-8016-fdb51ee79d91
md"## `Robot`, `hop_to!`, `verify`"

# ╔═╡ 118d65bb-ea24-42a5-ab0a-f2bb6a32d098
begin
	# build a robot with a certain path constructed via hop_to!
	robot = Robot(top)
	hop_to!(robot, 2, top)
	hop_to!(robot, 3, top)
	hop_to!(robot, 7, top)
	hop_to!(robot, 6, top)

	# not done bc didn't return to base.
	@test ! robot.done

	# try to hop to an impossible node (not joined to 6)
	@test_throws AssertionError hop_to!(robot, 5, top)

	# alt way of making a trail
	alt_robot = Robot([1, 2, 3, 7, 6], top)
	@test robot.trail == alt_robot.trail

	# verify the robot makes sense
	verify(alt_robot, top)
	verify(robot, top)
	alt_robot.edge_visit[1, 1] = true #  not valid anymore...
	@test_throws AssertionError verify(alt_robot, top)

	# finish a robot's path
	finished_robot = deepcopy(robot)
	hop_to!(finished_robot, 7, top)
	hop_to!(finished_robot, 8, top)
	hop_to!(finished_robot, 1, top)
	@test ! finished_robot.done
	hop_to!(finished_robot, 1, top)
	@test finished_robot.done
end

# ╔═╡ 69d091d8-c8fa-48cd-9d1d-1750e604ec55
viz_setup(top, robots=[robot])

# ╔═╡ cae311a4-0c0d-42ef-a599-63c84943c6b3
md"## probability model"

# ╔═╡ e4212d0f-fb28-40a2-83c3-43db5c2cd94b
# traverses 3 lo-risk, 1 hi-risk
@test π_robot_survives(robot.trail, top) ≈ ω["lo"] ^ 3 * ω["hi"]

# ╔═╡ 31731f25-e2d3-47b5-bcf0-e284de56e36e
@test 𝔼_nb_robots_survive([robot], top) ≈ π_robot_survives(robot.trail, top)

# ╔═╡ ddab2b7f-ffdf-478a-8d03-31c38ba1eb39
@test π_robot_visits_node_j(robot, 2, top) ≈ ω["lo"] 

# ╔═╡ 584e4cb3-fe1f-4d69-aa7e-fff6fa29a906
@test π_robot_visits_node_j(robot, 3, top) ≈ ω["lo"] ^ 2

# ╔═╡ 8fd64509-25a7-4126-b97d-63aeeb47a971
@test π_robot_visits_node_j(robot, 7, top) ≈ ω["lo"] ^ 3

# ╔═╡ c5ffab03-7c6f-4da7-b47e-0a8cd1c64fd3
@test π_robot_visits_node_j(robot, 6, top) ≈ π_robot_survives(robot.trail, top)

# ╔═╡ c08a26c8-a11d-4165-b73c-b1916f37e894
@test 𝔼_reward([robot], top) ≈ 
	# dies hopping to 2 (collects only node 1 reward)
	(1 - ω["lo"]) * r["lo"]  + 
	# dies hopping to 3 (surives hop to 2 first). collect reward at 1 and 2
	ω["lo"] * (1 - ω["lo"]) * (r["lo"] + r["hi"]) + 
	# dies hopping to 7.
	ω["lo"] ^ 2 * (1 - ω["lo"]) * (2 * r["lo"] + r["hi"]) + 
	# dies hopping to 6
	ω["lo"] ^ 3 * (1 - ω["hi"]) * (3 * r["lo"] + r["hi"]) + 
	# survives all
	π_robot_survives(robot.trail, top) * (4 * r["lo"] + r["hi"])

# ╔═╡ a46e2c9a-0d18-4501-89f1-f48cbca6112c
begin
	nodes_not_visisted = [10, 11, 9, 8, 4, 5]
	for j in nodes_not_visisted
		@test π_robot_visits_node_j(robot, j, top) == 0.0
	end
end

# ╔═╡ 2048c517-bb28-4a29-a1b2-8dc86bcc940a
begin
	local robots = [
		Robot([1, 2, 3, 4], top)
	]
	# node 5 not visisted...
	@test π_some_robot_visits_node_j(robots, 5, top) == 0.0
	# just one robot. prob some node visists node 4 is prob this single robot visits
	#   node 4.
	π_some_robot_visits_node_4 = π_some_robot_visits_node_j(robots, 4, top)
	@test π_some_robot_visits_node_4 ≈ π_robot_visits_node_j(robots[1], 4, top)

	# another robot that also visits node 4.
	local robots = [
		Robot([1, 2, 3, 4], top),
		Robot([1, 8, 7, 6, 4], top),
	]
	π_some_robot_visits_node_4 = π_some_robot_visits_node_j(robots, 4, top)
	# 1 - both robots die visiting node 4
	@test π_some_robot_visits_node_4 ≈ 1.0 - (1 - π_robot_visits_node_j(robots[1], 4, top)) * (1 - π_robot_visits_node_j(robots[2], 4, top))
	
	@test η_r(1, 2, top, robots) < η_r(1, 2, top) # cuz node 2 visited alraedy
	@test η_r(1, 9, top, robots) ≈ MOACOTOP.ϵ + η_r(1, 9, top) # cuz node 9 not visisted
	# robots
	# π_some_robot_visits_node_j(robots, 9, top)
end

# ╔═╡ 697915c7-ccfb-4d47-ab7f-5e5046ede84a
md"## test utils

function for uniqueness of solutions
"

# ╔═╡ 774f4cba-73d6-4568-ac14-6829439a0a37
begin
	robots = [
		Robot([1, 2, 3, 7, 6], top),
		Robot([1, 2], top)
	]
	other_robots = [
		Robot([1, 2, 3, 7, 6], top),
		Robot([1], top)
	]
	@test same_trail_set(robots, reverse(robots))
	@test ! same_trail_set(robots, other_robots)
end

# ╔═╡ 37cb7378-d2f4-4bce-ba66-421f88a006f7
md"unique functions"

# ╔═╡ b21f5afe-f033-4489-b0fb-1ca5db0ff106
begin
	# make list of solutions with unsorted r.
	r_obj = [4, 6, 3, 1, 2, 6]
	s_obj = [1, 2, 3, 4, 5, 2]
	my_solns = [Soln(top) for i = 1:6]
	for i = 1:6
		my_solns[i] = Soln([deepcopy(robot)], Objs(r_obj[i], s_obj[i]))
	end
	
	# one objective is not unique
	@test length(unique_solns(my_solns, :objs)) == 5

	# all robot trails the same.
	@test length(unique_solns(my_solns, :robot_trails)) == 1
	# modify one robot's trail. now there are two unique solns
	hop_to!(my_solns[1].robots[1], 4, top)
	@test length(unique_solns(my_solns, :robot_trails)) == 2

	# still two unique cuz robot 2 same as 1
	hop_to!(my_solns[2].robots[1], 4, top)
	@test length(unique_solns(my_solns, :robot_trails)) == 2

	# now three unique trails
	hop_to!(my_solns[2].robots[1], 5, top)
	@test length(unique_solns(my_solns, :robot_trails)) == 3
end

# ╔═╡ 0a61eae8-f448-4dde-ae5c-1ce83c47e1ea
md"pareto front"

# ╔═╡ 0fe292d4-dfd4-4172-93bb-33041085ea66
function rand_obj()
	x = rand(2)
	if x[2] < 1 - x[1]^2
		return x
	else 
		return rand_obj()
	end
end	

# ╔═╡ feb5a1fe-c2e5-4add-86cd-e971ab43b4df
many_solns = [Soln([robot], Objs(rand_obj()...)) for i = 1:100]

# ╔═╡ 9a44572b-52ed-41fa-b799-637632e6ee30
viz_Pareto_front(many_solns)

# ╔═╡ 9aff0981-9d33-4939-bc47-17bb19a21107
pareto_solns = get_pareto_solns(many_solns, false)

# ╔═╡ abdf7715-2c3b-4482-84b5-fc54865fe7f8
# no Pareto solns dominated
@test all([nondominated(p, many_solns) for p in pareto_solns])

# ╔═╡ db2d3a19-ef53-4f50-8407-e333dd69f7e5
# no others nondominated
@test sum([nondominated(s, many_solns) for s in many_solns]) == length(pareto_solns)

# ╔═╡ b41cf77e-1db2-4806-ac93-e3c931d887e8
md"test some edge cases"

# ╔═╡ 3c227603-3d54-41ae-a8b0-719bd704f1fb
edge_cases = shuffle(
	[
		Soln([robot], Objs(0.1, 0.9)),
		Soln([robot], Objs(0.3, 0.7)),
		Soln([robot], Objs(0.3, 0.5)), # not Pareto
		Soln([robot], Objs(0.3, 0.4)), # not Pareto
		Soln([robot], Objs(0.2, 0.2)), # not Pareto
		Soln([robot], Objs(0.3, 0.7)), # a repeat
		Soln([robot], Objs(0.3, 0.7)), # a repeat
		Soln([robot], Objs(0.2, 0.9)),
		Soln([robot], Objs(0.2, 0.7)),
		Soln([robot], Objs(1.0, 0.2)),
	]
)

# ╔═╡ 6c0a3207-a34e-4cbd-88bd-d351af524f6b
viz_Pareto_front(edge_cases)

# ╔═╡ c2bae287-434d-4cd0-88c6-48311bd39bdb
get_pareto_solns(edge_cases, false)

# ╔═╡ 35cbb528-6af9-4c6d-bcb5-42cad2c0d4bc
sort(edge_cases, by=x -> (x.objs.r, x.objs.s))

# ╔═╡ bdfac6f3-5290-43e7-a254-8a01dfb57cd8
@test length(get_pareto_solns(edge_cases, false)) == 3

# ╔═╡ c5caf994-f84c-42b4-a658-3eae4adaed55
@test length(get_pareto_solns(edge_cases, true)) == 5

# ╔═╡ 1139b683-6d99-4bad-b15a-993596c38d89
md"area indicator"

# ╔═╡ a8403660-c62f-4e2e-a3f9-909c47b1c86a
# when a single solution, jsut a rectangle
@test area_indicator([Soln([robot], Objs(0.3, 0.7))], 1.0, 1) ≈ 0.3 * 0.7

# ╔═╡ a3a90171-369d-4cd4-b254-bd751daec913
# a few rectangles. included redundancies
some_pareto_solns = shuffle(
	[
		Soln([robot], Objs(0.2, 0.8)),
		Soln([robot], Objs(0.2, 0.8)), # a repeat
		Soln([robot], Objs(0.2, 0.8)), # a repeat
		Soln([robot], Objs(0.4, 0.6)),
		Soln([robot], Objs(0.8, 0.2)),
		Soln([robot], Objs(0.8, 0.2)), # a repeat
	]
)

# ╔═╡ 5057ec09-7c22-4b5a-b08b-080c981bd24a
@test length(unique_solns(some_pareto_solns, :objs)) == 3

# ╔═╡ 68ad3b54-6068-4bf5-a61a-aa76f3884c13
viz_Pareto_front(some_pareto_solns)

# ╔═╡ 0fe1cf66-476c-442e-bb9e-185e48c214b5
@test area_indicator(some_pareto_solns, 1.0, 1) ≈ 0.2 * 0.8 + 0.2 * 0.6 + 0.4 * 0.2

# ╔═╡ 5939d13c-8d55-4acb-939c-1aad2273256e
md"ants"

# ╔═╡ ad619a75-7b11-4e46-89dd-e4bc78891b3f
toy_ants = Ants(3)

# ╔═╡ 22032a98-1849-49e3-8d38-072bdcbedea3
@test toy_ants == [Ant(0.0), Ant(0.5), Ant(1.0)]

# ╔═╡ c17a2530-cf3a-437b-a567-40c3ff211efe
md"pheremone"

# ╔═╡ 0368e00b-7219-4a22-8b82-4d653d5352ab
begin
	pheremone = Pheremone(top)
	τ₀_r = pheremone.τ_r[1, 1]
	τ₀_s = pheremone.τ_s[1, 1]
	ρ = 0.8

	evaporate!(pheremone, ρ)
	evaporate!(pheremone, ρ)
	@test all(pheremone.τ_r .≈ ρ ^ 2 * τ₀_r)
	@test all(pheremone.τ_s .≈ ρ ^ 2 * τ₀_s)
end

# ╔═╡ 8b7f40ac-4897-408f-82db-738e30dd6a21
begin
	# construct a bogus solution with bogus objective values, to test lay!
	local r_obj = 40.0
	local s_obj = 20.0
	ℓ = 2
	solns = [
		Soln([
			Robot([1, 10, 11], top),
			Robot([1, 2, 3], top)
		],
			Objs(r_obj, 0.0)
		)
		
		Soln([
			Robot([1, 2, 3, 7, 3], top),
			Robot([1, 2, 3, 4, 5], top)
		],
			Objs(0.0, s_obj)
		)
	]

	# start with zero pheremone
	other_pheremone = Pheremone(
		zeros(top.nb_nodes, top.nb_nodes),
		zeros(top.nb_nodes, top.nb_nodes)
	)
	# lay on trails
	lay!(other_pheremone, solns)

	@test sum(other_pheremone.τ_r) ≈ r_obj / ℓ * 4
	@test sum(other_pheremone.τ_s) ≈ s_obj / ℓ * 8
	@test other_pheremone.τ_r[1, 10] ≈ r_obj / ℓ
	@test other_pheremone.τ_s[3, 7] ≈ other_pheremone.τ_s[7, 3] ≈ s_obj / ℓ
	@test other_pheremone.τ_s[2, 3] ≈ 2 * s_obj / ℓ
	
	viz_pheremone(other_pheremone, top, nlabels=true)
end

# ╔═╡ e8ee873e-f293-4bfe-a16e-1e2bd94375ff
Pheremone(top)

# ╔═╡ 27416841-058a-4f75-96df-1a280211d7b8
md"building a partial solution"

# ╔═╡ 2b732d95-6f41-4587-b13b-dcabd27b8978
begin
	@test next_node_candidates(Robot(top), top) == [1, 2, 8, 9, 10]
	
	local robot = Robot([1, 2, 3, 7, 3], top)
	@test next_node_candidates(robot, top) == [2, 4]
	viz_setup(top, robots=[robot])
end

# ╔═╡ d90314e5-b918-480a-825d-a0f55d730cc0
begin
	# lay a super powerful pheremone trail. then gotta go there.
	strong_pheremone = Pheremone(
		zeros(top.nb_nodes, top.nb_nodes),
		zeros(top.nb_nodes, top.nb_nodes)
	)
	# strong_pheremone
	strong_pheremone.τ_r[1, 2] = 1000.0
	strong_pheremone.τ_r[2, 3] = 1000.0
	strong_pheremone.τ_r[3, 7] = 1000.0
	strong_pheremone.τ_r[7, 8] = 1000.0
	strong_pheremone.τ_r[8, 1] = 1000.0
	r_soln = construct_soln(Ant(0.0), strong_pheremone, top)
	@assert r_soln.robots[1].trail == [1, 2, 3, 7, 8, 1, 1]

	strong_pheremone.τ_s[1, 10] = 1000.0
	strong_pheremone.τ_s[10, 11] = 1000.0
	s_soln = construct_soln(Ant(1.0), strong_pheremone, top)
	@assert s_soln.robots[1].trail[1:3] == [1, 10, 11]
	
	viz_soln(r_soln, top, nlabels=true)
end

# ╔═╡ 85435fc3-4304-4b37-9309-d9cd8595d643
res = mo_aco(top, verbose=true, nb_ants=100, nb_iters=100)

# ╔═╡ 6edc6d72-895e-4db9-9bac-0d83146f3e70
viz_progress(res)

# ╔═╡ 7656e735-9e8a-4302-892a-39f5257d20f6
begin
	x = range(0.0, 100.0, length=100)

	local fig = Figure()
	local ax = Axis(fig[1, 1], xlabel="x")
	for λ in 0.0:0.1:1.0
		lines!(x, x.^λ, label=rich("x", superscript("$λ")), color=get(ColorSchemes.batlow10, λ))
	end
	axislegend()
	fig
end

# ╔═╡ 55f58c9c-ee63-47ef-b696-c784a735a32c
@bind λ PlutoUI.Slider(0.0:0.1:1.0)

# ╔═╡ 7ff66066-3a15-4155-81ff-9ef655c0bcef
begin
	local x = rand(100)
	local y = rand(100)

	local fig = Figure()
	local ax = Axis(fig[1, 1], xlabel="obj 1", ylabel="prob of selecting")
	scatter!(x, x .^ λ .* y .^ (1-λ) / sum(x .^ λ .* y .^ (1-λ)))
	ylims!(0.0, 2 / 100)
	fig
end

# ╔═╡ 6e3131d5-3499-4b42-8e4f-4d38472424a8
md"## simulated annealing moves"

# ╔═╡ e1c9e8d9-773b-4713-a770-95edd56ea8cd
function generate_sa_top()
	g = MetaDiGraph(SimpleGraph(11))
	# add edges
	edge_list = [
		# branch
		(1, 9),
		# branch
		(1, 10),
		(10, 11, ω["hi"]),
		# cycle
		(1, 8),
		(8, 7),
		(7, 6),
		(6, 4),
		(4, 3),
		(3, 2),
		(2, 1),
		# extra
		(3, 6),
		# bridge off cycle
		(4, 5),
		# shortcut in cycle
		(7, 3),
	]
	for (i, j) in edge_list
		add_edge!(g, i, j, :ω, 1.0)
		add_edge!(g, j, i, :ω, 1.0)
	end
	for v = 1:nv(g)
		set_prop!(g, v, :r, 1.0)
	end
	
	return TOP(nv(g), g, 2)
end

# ╔═╡ 11905c84-4de9-4a50-a3b0-efddd80218af
sa_top = generate_sa_top()

# ╔═╡ 8b307b88-1ab9-4b2b-9a56-f48f725af487
viz_setup(sa_top, depict_r=false, depict_ω=false)

# ╔═╡ 3cf810a9-b10f-4b1f-b0bd-84d50ce51776
begin
	local robot = Robot([1, 2, 3, 7, 8, 1, 1], sa_top)
	for i = 1:1000
		robot, perturbation = perturb_trail(robot, sa_top)
		println(perturbation)
		println(robot.trail)
	end
end

# ╔═╡ 0dfc5db7-d228-4fdd-8c89-8b1a0a1afd0c
MOACOTOP._attempt_node_deletion!(
	Robot(
		[1, 9, 1, 10, 11, 10, 1, 2, 3, 4, 3, 7, 6, 4, 5, 4, 6, 3, 6, 7, 8, 1, 1], 
		sa_top
		),
	sa_top
)

# ╔═╡ 65f2d1a8-7b0f-4b41-aa1e-429a18236ed1
viz_setup(
	sa_top, depict_r=false, depict_ω=false, 
	robots=[
		Robot(
		[1, 2, 3, 4, 6, 7, 8, 1, 1], 
		sa_top
		)
	]
)

# ╔═╡ 75129959-6371-492e-a873-d8380cdda6c8
begin
	local robot = Robot([1, 2, 3, 4, 6, 7, 8, 1, 1], sa_top)
	local n = length(robot.trail)
	println("OG robot trail: ", robot.trail, "\n")
	verify(robot, sa_top)

	if MOACOTOP._attempt_node_grab!(robot, sa_top)
		println("node grab successful")
		println("new robot trail: ", robot.trail, "\n")
	end

	if MOACOTOP._attempt_node_insertion!(robot, sa_top)
		println("node insertion successful")
		println("new robot trail: ", robot.trail, "\n")
	end

	if MOACOTOP._attempt_node_deletion!(robot, sa_top)
		println("node deletion successful")
		println("new robot trail: ", robot.trail, "\n")	
	end

	if MOACOTOP._attempt_node_substitution!(robot, sa_top)
		println("node subs successful")
		println("new robot trail: ", robot.trail, "\n")	
	end

	if MOACOTOP._attempt_node_delete_segment!(robot, sa_top, verbose=true)
		println("node subs successful")
		println("new robot trail: ", robot.trail, "\n")	
	end
	
	verify(robot, sa_top)
end

# ╔═╡ e4fca97f-77b1-42bf-8b4c-bf74fcb43389
begin
	local top = complete_graph_top(6, 2, Normal(1.0, 1.0), Normal(1.0, 1.0))
	local robot = Robot([1, 2, 3, 4, 1, 1], top)
	local n = length(robot.trail)
	println("OG robot trail: ", robot.trail, "\n")
	verify(robot, top)

	if MOACOTOP._attempt_node_swap!(robot, top)
		println("node swap successful")
		println("new robot trail: ", robot.trail, "\n")	
	end
	
	verify(robot, top)
	viz_setup(top, robots=[robot], depict_r=false, depict_ω=false)
end

# ╔═╡ 9b8b996f-355b-4eec-9508-d63d40907776
md"does the perturb trail eventually reach these target trails?"

# ╔═╡ ac33ea80-d03e-4f6b-90ef-3294209e396c
viz_setup(sa_top, depict_r=false, depict_ω=false)

# ╔═╡ cc136635-bcef-4c26-b5d2-af98c80543f8
target_trails = [
	[1, 9, 1, 1],
	[1, 1],
	[1, 9, 1, 10, 11, 1, 1],
	[1, 2, 3, 7, 8, 1, 1]
]

# ╔═╡ b0b35b2b-4e9e-4ff4-8bab-bb15f6106f57
begin
	target_trails_hit = [false for t = 1:length(target_trails)]
	sa_robot = Robot([1, 10, 1, 1], sa_top)
	verify(sa_robot, sa_top)

	n_perturbs = 10000
	perturbs = [:blah for i = 1:n_perturbs]
	for i = 1:n_perturbs
		# println("starting trail: ", sa_robot.trail)
		sa_robot, perturbs[i] = perturb_trail(sa_robot, sa_top, verbose=false)
		verify(sa_robot, sa_top)
		for (t, target_trail) in enumerate(target_trails)
			if sa_robot.trail == target_trail
				target_trails_hit[t] = true
			end
		end
		if all(target_trails_hit)
			break
		end
	end
	target_trails_hit
end

# ╔═╡ 2cc7f15c-a59e-44aa-a60f-422714fad8f0
a_star(top.g, 1, 7)

# ╔═╡ a08467cc-7373-40bc-bad3-3b4f85fdfc4f
for perturb in unique(perturbs)
	println(perturb, " count: ", count(==(perturb), perturbs))
end

# ╔═╡ 9dc772d9-0de7-4fc1-b69b-edcb61cd7681
viz_setup(sa_top, depict_r=false, depict_ω=false, robots=[sa_robot])

# ╔═╡ 04fe7fe8-9876-4837-8a00-ea20e39e991c
sa_robot.trail

# ╔═╡ Cell order:
# ╠═d493a41c-3879-11ee-32aa-052ae56d5240
# ╟─2d6e9814-74e5-4e07-9980-b3f6c06863e9
# ╠═305a8d3c-98c8-4ca2-baa8-24cbd1f74178
# ╠═10219d1e-6927-4618-8f02-bb08721587e0
# ╠═5bbbfd5c-d28e-4dcb-85c7-892599f49ca5
# ╠═d1349d2b-4956-4d42-a93f-7f666f2444d2
# ╟─24531d6e-18c1-452d-8016-fdb51ee79d91
# ╠═118d65bb-ea24-42a5-ab0a-f2bb6a32d098
# ╠═69d091d8-c8fa-48cd-9d1d-1750e604ec55
# ╟─cae311a4-0c0d-42ef-a599-63c84943c6b3
# ╠═e4212d0f-fb28-40a2-83c3-43db5c2cd94b
# ╠═31731f25-e2d3-47b5-bcf0-e284de56e36e
# ╠═ddab2b7f-ffdf-478a-8d03-31c38ba1eb39
# ╠═584e4cb3-fe1f-4d69-aa7e-fff6fa29a906
# ╠═8fd64509-25a7-4126-b97d-63aeeb47a971
# ╠═c5ffab03-7c6f-4da7-b47e-0a8cd1c64fd3
# ╠═c08a26c8-a11d-4165-b73c-b1916f37e894
# ╠═a46e2c9a-0d18-4501-89f1-f48cbca6112c
# ╠═2048c517-bb28-4a29-a1b2-8dc86bcc940a
# ╟─697915c7-ccfb-4d47-ab7f-5e5046ede84a
# ╠═774f4cba-73d6-4568-ac14-6829439a0a37
# ╟─37cb7378-d2f4-4bce-ba66-421f88a006f7
# ╠═b21f5afe-f033-4489-b0fb-1ca5db0ff106
# ╟─0a61eae8-f448-4dde-ae5c-1ce83c47e1ea
# ╠═0fe292d4-dfd4-4172-93bb-33041085ea66
# ╠═feb5a1fe-c2e5-4add-86cd-e971ab43b4df
# ╠═9a44572b-52ed-41fa-b799-637632e6ee30
# ╠═9aff0981-9d33-4939-bc47-17bb19a21107
# ╠═abdf7715-2c3b-4482-84b5-fc54865fe7f8
# ╠═db2d3a19-ef53-4f50-8407-e333dd69f7e5
# ╟─b41cf77e-1db2-4806-ac93-e3c931d887e8
# ╠═3c227603-3d54-41ae-a8b0-719bd704f1fb
# ╠═6c0a3207-a34e-4cbd-88bd-d351af524f6b
# ╠═c2bae287-434d-4cd0-88c6-48311bd39bdb
# ╠═35cbb528-6af9-4c6d-bcb5-42cad2c0d4bc
# ╠═bdfac6f3-5290-43e7-a254-8a01dfb57cd8
# ╠═c5caf994-f84c-42b4-a658-3eae4adaed55
# ╟─1139b683-6d99-4bad-b15a-993596c38d89
# ╠═a8403660-c62f-4e2e-a3f9-909c47b1c86a
# ╠═a3a90171-369d-4cd4-b254-bd751daec913
# ╠═5057ec09-7c22-4b5a-b08b-080c981bd24a
# ╠═68ad3b54-6068-4bf5-a61a-aa76f3884c13
# ╠═0fe1cf66-476c-442e-bb9e-185e48c214b5
# ╟─5939d13c-8d55-4acb-939c-1aad2273256e
# ╠═ad619a75-7b11-4e46-89dd-e4bc78891b3f
# ╠═22032a98-1849-49e3-8d38-072bdcbedea3
# ╟─c17a2530-cf3a-437b-a567-40c3ff211efe
# ╠═0368e00b-7219-4a22-8b82-4d653d5352ab
# ╠═8b7f40ac-4897-408f-82db-738e30dd6a21
# ╠═e8ee873e-f293-4bfe-a16e-1e2bd94375ff
# ╟─27416841-058a-4f75-96df-1a280211d7b8
# ╠═2b732d95-6f41-4587-b13b-dcabd27b8978
# ╠═d90314e5-b918-480a-825d-a0f55d730cc0
# ╠═85435fc3-4304-4b37-9309-d9cd8595d643
# ╠═6edc6d72-895e-4db9-9bac-0d83146f3e70
# ╠═7656e735-9e8a-4302-892a-39f5257d20f6
# ╠═55f58c9c-ee63-47ef-b696-c784a735a32c
# ╠═7ff66066-3a15-4155-81ff-9ef655c0bcef
# ╟─6e3131d5-3499-4b42-8e4f-4d38472424a8
# ╠═e1c9e8d9-773b-4713-a770-95edd56ea8cd
# ╠═11905c84-4de9-4a50-a3b0-efddd80218af
# ╠═8b307b88-1ab9-4b2b-9a56-f48f725af487
# ╠═3cf810a9-b10f-4b1f-b0bd-84d50ce51776
# ╠═0dfc5db7-d228-4fdd-8c89-8b1a0a1afd0c
# ╠═65f2d1a8-7b0f-4b41-aa1e-429a18236ed1
# ╠═75129959-6371-492e-a873-d8380cdda6c8
# ╠═e4fca97f-77b1-42bf-8b4c-bf74fcb43389
# ╟─9b8b996f-355b-4eec-9508-d63d40907776
# ╠═ac33ea80-d03e-4f6b-90ef-3294209e396c
# ╠═cc136635-bcef-4c26-b5d2-af98c80543f8
# ╠═b0b35b2b-4e9e-4ff4-8bab-bb15f6106f57
# ╠═2cc7f15c-a59e-44aa-a60f-422714fad8f0
# ╠═a08467cc-7373-40bc-bad3-3b4f85fdfc4f
# ╠═9dc772d9-0de7-4fc1-b69b-edcb61cd7681
# ╠═04fe7fe8-9876-4837-8a00-ea20e39e991c
