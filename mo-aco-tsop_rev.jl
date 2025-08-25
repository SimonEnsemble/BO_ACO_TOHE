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

# ╔═╡ d04e8854-3557-11ee-3f0a-2f68a1123873
begin
	import Pkg; Pkg.activate("aco")
	using Revise, Graphs, GraphMakie, MetaGraphs, CairoMakie, ColorSchemes, Distributions, NetworkLayout, Random, PlutoUI, StatsBase, JLD2

	import AlgebraOfGraphics: set_aog_theme!, firasans, wongcolors
	set_aog_theme!(fonts=[firasans("Light"), firasans("Light")])
	the_size = (600, 500)
	update_theme!(
		fontsize=20, 
		linewidth=2,
		markersize=14,
		titlefont=firasans("Light"),
		size=the_size
	)

	push!(LOAD_PATH, "src")
	using MOACOTOP
end

# ╔═╡ e136cdee-f7c1-4add-9024-70351646bf24
TableOfContents()

# ╔═╡ 2bfd9bc7-a6d9-4fa3-810a-710ebde2bd5c
Threads.nthreads()

# ╔═╡ 73a53f9c-e981-44d6-9b0c-00a6fca5c5b8
md"# 🔘 settings"

# ╔═╡ 8b6be951-185f-488a-9ef1-f3b40ce9ecc8
md"try loading saved results? $(@bind load_saved_res CheckBox(default=true))"

# ╔═╡ 9b00deb7-6edb-45fe-bc55-00e8c581c289
md"save results? $(@bind save_res CheckBox(default=true))"

# ╔═╡ cb8824e4-50d5-4fc5-a69a-5f81d51c0c8c
results_dir = "search_results"

# ╔═╡ 2874cce9-86ec-48b7-87f6-a2d6d11b7f17
mkpath(results_dir)

# ╔═╡ 063a4b94-05f3-4e78-8059-7ab1886b521b
md"run simualted annealing? $(@bind run_sa CheckBox(default=false))"

# ╔═╡ 5b8823d0-b0c9-49df-b69b-7c2a3370245b
md"run random? $(@bind run_random CheckBox(default=false))"

# ╔═╡ e4f7f56b-f4d2-4f90-98d0-c2164c6e9d19
md"run pheromone/heuristic ablation study? $(@bind run_ablation CheckBox(default=false))"

# ╔═╡ 0fb3f9be-454b-4ff1-a619-91e67ec92025
begin
	problem_instance = "art museum"
	problem_instance = "nuclear power plant"
	problem_instance = "block model"
	# "block model", "nuclear power plant
	# ["power_plant", "art_museum", "random", "block model", "complete"], 

	nb_iters = 100000

	n_runs = 4

	run_checks = false

	savetag = "_$(problem_instance)_$(nb_iters)_iter_$(n_runs)_runs"

	search_results = Dict()
end

# ╔═╡ 613ad2a0-abb7-47f5-b477-82351f54894a
md"

!!! warning \"BO-ACO of RTOHE problem\"
	BO = bi-objective

	ACO = ant colony optimization

	RTOHE = robot team orienteering in a hazardous environment

# problem definition
"

# ╔═╡ bdb5d550-13f6-4d8d-9a74-14b889efe7a2
if problem_instance == "nuclear power plant"
	top = darpa_urban_environment(2)
elseif problem_instance == "art museum"
	top = art_museum(3)
elseif problem_instance == "random"
	top = generate_random_top(30, 5)
elseif problem_instance == "block model"
	Random.seed!(5)
	local p_interconnect = 0.025
	# complicated graph with few robots
	# to showcase when multiple robot trails better.
	top = block_model(
		# number of nodes
		[12, 8], 

		# number of robots
		2,
		
		# connection probabilities
		[
			0.4 p_interconnect p_interconnect p_interconnect; 
			p_interconnect 0.3 p_interconnect p_interconnect;
			p_interconnect p_interconnect 0.4 p_interconnect;
			p_interconnect p_interconnect p_interconnect 0.8;
		],
		
		# reward dist'n
		[Normal(1.0, 0.5), Normal(5.0, 2.0), Normal(6.0, 1.0), Normal(6.0, 3.0)],
		
		# survival prob dist'n
		[
			Normal(0.9, 0.3) for i = 1:4, j = 1:4
		],
	)
elseif problem_instance == "complete"
	top = complete_graph_top(
		25, 2, Normal(1.0, 1.0), Normal(0.75, 0.2)
	)	
end

# ╔═╡ 76ecc4c1-39b7-4b3c-b98c-cdb1cdcf7eba
@assert get_ω(top.g, 1, 1) == 1.0

# ╔═╡ f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
md"## viz problem setup"

# ╔═╡ e3946d78-b7d4-4484-9e00-dc20d0457293
begin
	function adjust_layout!(i::Int, Δ_x::Float64, Δ_y::Float64)
		layout[i] = layout[i] + Point2{Float64}(Δ_x, Δ_y)
	end
	
	if problem_instance == "art museum"
		layout = art_museum_layout(8.0)
		robot_radius = 0.45
	elseif problem_instance == "nuclear power plant"
		layout = Spring(iterations=350, C=2.0, initialtemp=1.5)(top.g)
		robot_radius = 0.3
		# adjustments
		# layout
		layout = power_plant_layout(12.0)
		layout = Spring(
			iterations=5, C=3.2, initialtemp=1.5, initialpos=layout
		)(top.g)
		# adjustments
		local Δ = 0.5
		adjust_layout!(37, 0.0, -Δ)
		adjust_layout!(33, -Δ, 0.0)
		adjust_layout!(28, -Δ, 3*Δ)
		adjust_layout!(19, -2*Δ, Δ)
		adjust_layout!(42, 0.0, -Δ)
		adjust_layout!(49, -2*Δ, 0.0)
		adjust_layout!(50, -Δ, 0.0)
		adjust_layout!(30, 0.0, -Δ)
		adjust_layout!(14, Δ, -2*Δ)
		adjust_layout!(68, -Δ, 0.0)
		adjust_layout!(64, -Δ, 0.0)
		adjust_layout!(67, -1.5*Δ, 0.0)
		adjust_layout!(60, -1.5*Δ, 0.0)
		adjust_layout!(73, 0.5*Δ, 0.0)
		adjust_layout!(59, Δ, 0.0)
		adjust_layout!(56, 1.5*Δ, Δ)
		adjust_layout!(22, 1.5*Δ, 0.0)
		adjust_layout!(43, 0.5*Δ, Δ/2)
		adjust_layout!(17, 0.0, Δ/2)
		robot_radius = 0.565
	else
		layout = Spring(iterations=100, C=10.0, initialtemp=3.5)(top.g)
		for i = 1:length(layout)
			layout[i] = layout[i] * 0.2
		end
		local Δ = 1.0
		adjust_layout!(20, -2*Δ, 0.0)
		adjust_layout!(21, 0.0, -Δ)
		adjust_layout!(18, -1.5*Δ, 0.0)
		adjust_layout!(5, -Δ/2, 0.0)
		adjust_layout!(7, 0.0, Δ/2)
		adjust_layout!(13, 0.0, -Δ/2)
		adjust_layout!(4, 0.0, -Δ/2)
		adjust_layout!(8, Δ/2, 0.0)
		adjust_layout!(2, Δ/2, 0.0)
		adjust_layout!(19, -2.2*Δ, -Δ/2)
		robot_radius = 0.3
	end
end

# ╔═╡ 79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
begin	
	local fig = viz_setup(
		top, nlabels=true, robot_radius=robot_radius,
		savename=problem_instance * "_full_setup", 
		depict_r=false, depict_ω=true, show_robots=true, 
		layout=layout, node_size=23,
		show_colorbars=top.name == "art museum"
	)
	local ax =  current_axis()
	if problem_instance == "art museum"
		for (i, pos) in zip(1:2, [(2.75, 3.6), (3.75, -1.75)])
			text!(ax, pos, text="floor #$i", 
				align=(:center, :center), font=firasans("Light")
			)
		end
	elseif top.name == "synthetic (2 communities)"
		for (i, pos) in zip(1:2, [(-3.5, 0.0), (2, 1.5)])
			text!(ax, pos, text="community\n#$i", 
				align=(:center, :center), font=firasans("Light")
			)
		end
	elseif problem_instance == "nuclear power plant"
		resize!(fig.scene, (the_size[1] * 1.2, the_size[1] * 1.2))
		for (i, pos) in zip(1:2, [(4, 2.5), (-7.0, 3.5)])
			text!(ax, pos, text="floor #$i", 
				align=(:center, :center), font=firasans("Light")
			)
		end
	end
	resize_to_layout!(fig)
	save("paper/" * top.name * "_full_setup.pdf", fig)
	fig
end

# ╔═╡ 9d44f37d-8c05-450a-a448-7be50387499c
md"# MO-ACO
"

# ╔═╡ cdfdf924-d0f5-452f-9c94-eef7592c374d
ρ = 0.9 # evaporation rate

# ╔═╡ 1aecacee-9df1-4ddc-8497-3bea9c635bfa
nb_ants = 100

# ╔═╡ 8a6c6d9a-e15a-4f22-9d86-00e591b15693
md"set seeds same to give each the same initial condition for fair comparison."

# ╔═╡ 17117efa-c63e-4193-a99b-c7423367fc06
my_seeds = [rand(1:typemax(Int)) for r = 1:n_runs]

# ╔═╡ 4e0244cb-f853-4156-ba5f-392592a12d9d
md"

## 🐜 do it!
 BO-ACO with:

✔ heuristic
✔ pheremone
✔ shared pheremone trail among robots.
"

# ╔═╡ a8e27a0e-89da-4206-a7e2-94f796cac8b4
begin
	# filename for storage of results
	local filename = joinpath(results_dir, "aco_$savetag.jld2")

	# if load save results, try.
	if load_saved_res & isfile(filename)
		@info "loading previous search results"
		local results = load(filename, "results")
	else
		local results = [MO_ACO_run() for r = 1:n_runs]
		
		Threads.@threads for r = 1:n_runs
			results[r] = mo_aco(
				top, 
				verbose=false, 
				nb_ants=nb_ants, 
				nb_iters=nb_iters,
				use_heuristic=true,
				use_pheremone=true,
				run_checks=run_checks,
				ρ=ρ,
				my_seed=my_seeds[r]
			)
		end
		
		if save_res
			@info "writing results to file"
			jldsave(filename; results)
		end
	end

	search_results["ACO"] = results
end

# ╔═╡ 3a1caac3-dd55-42fb-91b2-2f9c3001c22c
md"
## analyze performance

area indicator at end of search:"

# ╔═╡ 793286fa-ff36-44bb-baaf-e7fd819c5aa4
[res.areas[end] for res in search_results["ACO"]]

# ╔═╡ 92d564b1-17f1-4fd1-9e76-8ea1b65c127a
viz_progress(search_results["ACO"], savename="progress")

# ╔═╡ 3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
md"
## 👓 inspect solutions

run browser: $(@bind run_id PlutoUI.Slider(1:n_runs))

solution browser: $(@bind soln_id PlutoUI.Slider(1:length(search_results[\"ACO\"][run_id].global_pareto_solns)))
"

# ╔═╡ f89383c4-e46c-4cc2-967a-11bd451ec486
search_results["ACO"][run_id].global_pareto_solns[soln_id].robots[1].trail

# ╔═╡ 9d49add3-8b03-402d-aa67-a173a74a2995
run_id

# ╔═╡ f2f8de8e-629c-45eb-81f2-9898777678ff
soln_id

# ╔═╡ b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
viz_soln(
	search_results["ACO"][run_id].global_pareto_solns[soln_id], top, 
	show_𝔼=true, layout=layout, robot_radius=robot_radius, 
	elabels=true, only_first_elabel=true
)

# ╔═╡ aca53592-e8d5-4640-951a-7acca6241ea3
ids_hl = [13, 20]#, 133, 178]

# ╔═╡ 4769582f-6498-4f14-a965-ed109b7f97d1
viz_Pareto_front(
	search_results["ACO"][run_id].global_pareto_solns, size=(300, 300), ids_hl=ids_hl, savename="pareto_front_$(top.name)", incl_legend=false
)

# ╔═╡ 60917dfc-8342-4bae-abec-d64eab350c15
for soln_id in ids_hl
	viz_soln(
		search_results["ACO"][run_id].global_pareto_solns[soln_id], top,
		show_𝔼=false, savename="a_soln_$soln_id", layout=layout, robot_radius=robot_radius, elabels=true, only_first_elabel=true
	)
end

# ╔═╡ 751c4203-88b1-40dd-9a96-926cd614aef8
viz_soln(
	search_results["ACO"][run_id].global_pareto_solns[soln_id], top, show_𝔼=false, 
	# savename="a_soln",
	layout=layout, robot_radius=robot_radius
)

# ╔═╡ e55fbea2-4865-498f-abeb-86f6db202b43
md"## viz pheremone"

# ╔═╡ 197ea13f-b460-4457-a2ad-ae8d63c5e5ea
viz_pheremone(
	search_results["ACO"][run_id].pheremone, top, 
	savename="paper/pheremone_$(top.name)", 
	layout=layout
)

# ╔═╡ 514851fe-da59-4885-9dc8-0c9fb0c02223
md"# baselines
"

# ╔═╡ 9d4ae33a-7fac-4a8d-b37a-29ab00b8056d
md"## 🧠 heuristic-guided search"

# ╔═╡ 67c9334e-1155-4ef3-8d75-030dcfc1e570
begin
	# filename for storage of results
	local filename = joinpath(results_dir, "heuristic_only_$(nb_iters)_iters.jld2")

	# if load save results, try.
	if load_saved_res & isfile(filename)
		@info "loading previous search results"
		local results = load(filename, "results")
	else
		local results = [MO_ACO_run() for r = 1:n_runs]
		Threads.@threads for r = 1:n_runs
			results[r] = mo_aco(
				top, 
				verbose=false, 
				nb_ants=nb_ants, 
				nb_iters=nb_iters,
				use_heuristic=true,
				use_pheremone=false,
				run_checks=run_checks,
				my_seed=my_seeds[r]
			)
		end
		
		if save_res
			@info "writing results to file"
			jldsave(filename; results)
		end
	end

	search_results["ACO (no pheromone)"] = results
end

# ╔═╡ 5defd4be-0e97-4826-96b6-8c2cc77e0c08
md"## 🐜 pheromone only
BO-ACO with:

✔ pheremone
✔ one pheremone trail for each robot."

# ╔═╡ 3b94a9a8-93c8-4e46-ae23-63374d368b16
begin
	# filename for storage of results
	local filename = joinpath(results_dir, "pheromone_only_$savetag.jld2")

	# if load save results, try.
	if load_saved_res & isfile(filename)
		@info "loading previous search results"
		local results = load(filename, "results")
	else
		local results = [MO_ACO_run() for r = 1:n_runs]
		Threads.@threads for r = 1:n_runs
			results[r] = mo_aco(
				top, 
				verbose=false, 
				nb_ants=nb_ants, 
				nb_iters=nb_iters,
				use_heuristic=false,
				use_pheremone=true,
				run_checks=run_checks,
				ρ=ρ,
				my_seed=my_seeds[r]
		)
		end
		
		if save_res
			@info "writing results to file"
			jldsave(filename; results)
		end
	end
		
	search_results["ACO (no heuristic)"] = results
end

# ╔═╡ b566ec79-c4a7-47b5-8620-e10549252554
md"## 🎲 random search"

# ╔═╡ 2400b72e-2d1a-4c2e-91c7-14c8ac92cc11
begin
	# filename for storage of results
	local filename = joinpath(results_dir, "random_$savetag.jld2")

	# if load save results, try.
	if load_saved_res & isfile(filename)
		@info "loading previous search results"
		local results = load(filename, "results")
	else
		local results = [MO_ACO_run() for r = 1:n_runs]
		Threads.@threads for r = 1:n_runs
			results[r] = mo_aco(
				top, 
				verbose=false, 
				nb_ants=nb_ants, 
				nb_iters=nb_iters,
				use_heuristic=false,
				use_pheremone=false,
				run_checks=run_checks,
				my_seed=my_seeds[r]
		)
		end
		
		if save_res
			@info "writing results to file"
			jldsave(filename; results)
		end
	end
		
	search_results["random"] = results
end

# ╔═╡ 8c1b4a18-2a7a-47b0-aeff-27014ff351a9
md"## 🔮 simulated annealing
"

# ╔═╡ c7aa05d2-824d-4744-845d-04c6ab3e1d80
md"iters. a bit different than ACO since gotta re-run for each number of iters.
factor into weights for aggregeated objectives and iters per single objective problem.
"

# ╔═╡ 1f49a5d2-46df-4750-8600-16c9a70d14d5
sa_iters = [10, 100, 1000, 10000, 100000] * nb_ants

# ╔═╡ f220ba3d-8c0e-4ee1-ae60-931eb77c0b03
cooling_schedule = CoolingSchedule(0.2, 0.95)

# ╔═╡ 7fccd71f-8864-443e-851a-af529eeb02f8
begin
	# filename for storage of results
	local filename = joinpath(results_dir, "sa_$savetag.jld2")

	# if load save results, try.
	if load_saved_res & isfile(filename)
		@info "loading previous search results"
		local results = load(filename, "results")
	else
		local results = [[MO_SA_Run()] for r = 1:n_runs]
		Threads.@threads for r = 1:n_runs
			results[r] = [mo_simulated_annealing(
					top, round(Int, sqrt(i)), round(Int, sqrt(i)), 
					# cooling schedule
					cooling_schedule, 
					my_seed=my_seeds[r], run_checks=run_checks,
					nb_trail_perturbations_per_iter=top.nb_robots,
					p_restart=0.05
				)
				for i in sa_iters
			]
		end
		
		if save_res
			@info "writing results to file"
			jldsave(filename; results)
		end
	end
		
	search_results["simulated annealing"] = results
end

# ╔═╡ c30ea441-6814-41b4-b9f2-458d701cebb6
viz_agg_objectives(
	search_results["simulated annealing"][1][2], 
	savename="simulated_annealing_convergence_$(top.name).pdf"
)

# ╔═╡ e9d3fa8a-8297-450f-a060-ba555205792a
begin
	local res_sa = search_results["simulated annealing"][1][end]
	
	local fig = Figure()
	local ax = Axis(fig[1, 1], xlabel="E(R)", ylabel="E(S)")
	scatter!(
		[s.objs.r for s in res_sa.pareto_solns], 
		[s.objs.s for s in res_sa.pareto_solns],
		color="orange", label="SA: # iters: $(res_sa.total_nb_iters/nb_ants)"
	)

	scatter!(
		[s.objs.r for s in search_results["ACO"][1].global_pareto_solns], 
		[s.objs.s for s in search_results["ACO"][1].global_pareto_solns],
		color="green", label="ACO: # iters $nb_iters"
	)
	axislegend()

	fig
end

# ╔═╡ 272b6d1a-0e4f-4f2e-90db-eb328569497c
md"## 👓 compare searches"

# ╔═╡ a9e167d0-8c86-4ad7-aac0-35beeb060324
algos = [
	"ACO", 
	"ACO (no heuristic)", 
	"ACO (no pheromone)", 
	"random", 
	"simulated annealing"
]

# ╔═╡ d9eb33a6-a374-4c20-bd18-dbf5a5c845eb
algo_to_color = Dict(
	"ACO" => wongcolors()[1],
	"ACO (no heuristic)" => wongcolors()[2],
	"ACO (no pheromone)" => wongcolors()[3],
	"random" => wongcolors()[4],
	"simulated annealing" => wongcolors()[7]
)

# ╔═╡ 0808a99f-1f55-4b0a-81e9-3f511c9f55d5
begin
	local fig = Figure(size=(700, 400))
	local ax = Axis(
		fig[1, 1], 
		xlabel="# iterations", 
		ylabel="Pareto-set quality",
		xscale=log10
	)
	for r = 1:n_runs
		for algo in algos
			local results = search_results[algo]
			if algo == "simulated annealing"
				scatter!(
					[sa_res.total_nb_iters for sa_res in results[r]] / nb_ants,
					[sa_res.area for sa_res in results[r]],
					strokewidth=1, strokecolor="gray",
					color=(algo_to_color[algo], 0.5),
					label=algo
				)
			else
				# ACOs
				lines!(
					1:results[r].nb_iters, results[r].areas, 
					label=algo, linewidth=3, color=(algo_to_color[algo], 0.5)
				)
			end
				
		end
	end
	xlims!(1, nb_iters)
	fig[1, 2] = Legend(
		fig, ax, "search algorithm", framevisible = false, unique=true
	)
	save("paper/ACO_performance_$(top.name).pdf", fig)
	fig
end

# ╔═╡ bf1f5784-52fa-4e24-ba2d-56aaf4e625c5
search_results["simulated annealing"][1]

# ╔═╡ de4b52e6-df86-42d6-b49a-df01d44b9a92
begin
	local fig = Figure(size=(700, 400))
	local ax = Axis(
		fig[1, 1], 
		xlabel="# iterations", 
		ylabel="Pareto-set quality",
		xscale=log10
	)
	for algo in algos
		local results = search_results[algo]
		
		if algo == "simulated annealing"
			iters = [sr.total_nb_iters for sr in results[1]] / nb_ants
			μ = [
				mean(results[r][i].area for r = 1:n_runs)
				for i = 1:length(iters)
			]
			σ = [
				std(results[r][i].area for r = 1:n_runs)
				for i = 1:length(iters)
			]
			scatter!(iters, μ,
				strokewidth=1, strokecolor="gray",
				color=(algo_to_color[algo], 0.5),
				label=algo
			)
			errorbars!(
				iters, μ, σ, whiskerwidth=10, color="gray"
			)
		else
			# ACO
			n = results[1].nb_iters
			
			μ = mean(results[r].areas for r = 1:n_runs)
			σ = [
				std(
					[results[r].areas[i] for r = 1:n_runs]
				) 
				for i = 1:n
			]
			
			lines!(
				1:n, μ, 
				label=algo, linewidth=3, color=algo_to_color[algo]
			)
			band!(1:n, μ .- σ, μ .+ σ, color=(algo_to_color[algo], 0.5))
		end
	end
	
	# SA
	local results = search_results["simulated annealing"]
	
	
	xlims!(1, nb_iters)
	fig[1, 2] = Legend(
		fig, ax, "search algorithm", framevisible = false, unique=true
	)
	save("paper/ACO_performance_banded_$(top.name).pdf", fig)
	fig
end

# ╔═╡ Cell order:
# ╠═d04e8854-3557-11ee-3f0a-2f68a1123873
# ╠═e136cdee-f7c1-4add-9024-70351646bf24
# ╠═2bfd9bc7-a6d9-4fa3-810a-710ebde2bd5c
# ╟─73a53f9c-e981-44d6-9b0c-00a6fca5c5b8
# ╟─8b6be951-185f-488a-9ef1-f3b40ce9ecc8
# ╟─9b00deb7-6edb-45fe-bc55-00e8c581c289
# ╠═cb8824e4-50d5-4fc5-a69a-5f81d51c0c8c
# ╠═2874cce9-86ec-48b7-87f6-a2d6d11b7f17
# ╟─063a4b94-05f3-4e78-8059-7ab1886b521b
# ╟─5b8823d0-b0c9-49df-b69b-7c2a3370245b
# ╟─e4f7f56b-f4d2-4f90-98d0-c2164c6e9d19
# ╠═0fb3f9be-454b-4ff1-a619-91e67ec92025
# ╟─613ad2a0-abb7-47f5-b477-82351f54894a
# ╠═bdb5d550-13f6-4d8d-9a74-14b889efe7a2
# ╠═76ecc4c1-39b7-4b3c-b98c-cdb1cdcf7eba
# ╟─f7717cbe-aa9f-4ee9-baf4-7f9f1d190d4c
# ╠═e3946d78-b7d4-4484-9e00-dc20d0457293
# ╠═79dd4f91-8a4a-4be1-8013-c9b6dfa56a75
# ╟─9d44f37d-8c05-450a-a448-7be50387499c
# ╠═cdfdf924-d0f5-452f-9c94-eef7592c374d
# ╠═1aecacee-9df1-4ddc-8497-3bea9c635bfa
# ╟─8a6c6d9a-e15a-4f22-9d86-00e591b15693
# ╠═17117efa-c63e-4193-a99b-c7423367fc06
# ╟─4e0244cb-f853-4156-ba5f-392592a12d9d
# ╠═a8e27a0e-89da-4206-a7e2-94f796cac8b4
# ╟─3a1caac3-dd55-42fb-91b2-2f9c3001c22c
# ╠═793286fa-ff36-44bb-baaf-e7fd819c5aa4
# ╠═92d564b1-17f1-4fd1-9e76-8ea1b65c127a
# ╟─3d98df3e-ec41-4685-b15d-bd99ec4bd5f7
# ╠═f89383c4-e46c-4cc2-967a-11bd451ec486
# ╠═9d49add3-8b03-402d-aa67-a173a74a2995
# ╠═f2f8de8e-629c-45eb-81f2-9898777678ff
# ╠═b3bf0308-f5dd-4fa9-b3a7-8a1aee03fda1
# ╠═aca53592-e8d5-4640-951a-7acca6241ea3
# ╠═4769582f-6498-4f14-a965-ed109b7f97d1
# ╠═60917dfc-8342-4bae-abec-d64eab350c15
# ╠═751c4203-88b1-40dd-9a96-926cd614aef8
# ╟─e55fbea2-4865-498f-abeb-86f6db202b43
# ╠═197ea13f-b460-4457-a2ad-ae8d63c5e5ea
# ╟─514851fe-da59-4885-9dc8-0c9fb0c02223
# ╟─9d4ae33a-7fac-4a8d-b37a-29ab00b8056d
# ╠═67c9334e-1155-4ef3-8d75-030dcfc1e570
# ╟─5defd4be-0e97-4826-96b6-8c2cc77e0c08
# ╠═3b94a9a8-93c8-4e46-ae23-63374d368b16
# ╟─b566ec79-c4a7-47b5-8620-e10549252554
# ╠═2400b72e-2d1a-4c2e-91c7-14c8ac92cc11
# ╟─8c1b4a18-2a7a-47b0-aeff-27014ff351a9
# ╟─c7aa05d2-824d-4744-845d-04c6ab3e1d80
# ╠═1f49a5d2-46df-4750-8600-16c9a70d14d5
# ╠═f220ba3d-8c0e-4ee1-ae60-931eb77c0b03
# ╠═7fccd71f-8864-443e-851a-af529eeb02f8
# ╠═c30ea441-6814-41b4-b9f2-458d701cebb6
# ╠═e9d3fa8a-8297-450f-a060-ba555205792a
# ╟─272b6d1a-0e4f-4f2e-90db-eb328569497c
# ╠═a9e167d0-8c86-4ad7-aac0-35beeb060324
# ╠═d9eb33a6-a374-4c20-bd18-dbf5a5c845eb
# ╠═0808a99f-1f55-4b0a-81e9-3f511c9f55d5
# ╠═bf1f5784-52fa-4e24-ba2d-56aaf4e625c5
# ╠═de4b52e6-df86-42d6-b49a-df01d44b9a92
