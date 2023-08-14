"""
    Objs(r, s)

store the two objectives: 𝔼(reward),  𝔼(# robots survive)
"""
struct Objs
	r::Float64 # 𝔼(reward)
	s::Float64 # 𝔼(# robots survive)
end

"""
    Soln(robots, objs)
    Soln(top) # initialize

store the solution to the TOP: the robots and the value of the two objectives.
"""
struct Soln
    robots::Vector{Robot}
    objs::Objs
end

# initialize
Soln(top::TOP) = Soln(
    [Robot(top) for k = 1:top.nb_robots], 
    Objs(NaN, NaN)
)

"""
    same_trail_set(robots_i, robots_j)

do the robots have the same sets of trails? true or false.
this is a set comparison. comparing sets of trails.
used for making sure we keep track of only *unique* solutions.
"""
function same_trail_set(robotsᵢ::Vector{Robot}, robotsⱼ::Vector{Robot})
	trails_i = Set([robot.trail for robot in robotsᵢ])
	trails_j = Set([robot.trail for robot in robotsⱼ])
	return trails_i == trails_j
end

"""
    sort_by_r!(solns, rev=false)
    sort_by_r(solns, rev=false)

sort list of solutions by the objective 𝔼[team reward].
needed to sort according to solutions on the Pareto front.
"""
function sort_by_r!(solns::Vector{Soln}; rev::Bool=false)
	# get list of first objective values
	rs = [soln.objs.r for soln in solns]
	# find out how to sort them
	ids = sortperm(rs, rev=rev)
	# do the sorting. the dot is important for modifying it !
	solns .= solns[ids]
end

function sort_by_r(solns::Vector{Soln}; rev::Bool=false)
    _solns = deepcopy(solns)
    sort_by_r!(_solns, rev=rev)
    return _solns
end

"""
    unique(solns, :objs)
    unique(solns, :robot_trails)

get unique list of solutions, in terms of (i) their objectives or (ii) the robot trail sets.
"""
function unique_solns(solns::Vector{Soln}, by::Symbol)
	@assert by in [:robot_trails, :objs]
	# start with assumption we gonna keep all of em
	ids_keep = [true for i = 1:length(solns)]
	for i = 1:length(solns)
		# throw out if there is one that is the same later.
		for j = i+1:length(solns)
			if by == :robot_trails
				if same_trail_set(solns[i].robots, solns[j].robots)
					ids_keep[i] = false
				end
			elseif by == :objs
				if solns[i].objs == solns[j].objs
					ids_keep[i] = false
				end
			end
		end
	end
	return solns[ids_keep]
end

"""
    get_pareto_solns(solns, keep_duplicates)

get the nondominated solutions from a list of solutions.
uses algo from here:
https://en.wikipedia.org/wiki/Maxima_of_a_point_set
"""
function get_pareto_solns(solns::Vector{Soln}, keep_duplicates::Bool)
    sorted_solns = sort_by_r(solns, rev=true) # highest to lowest
	largest_s_seen = -Inf
	ids_pareto = Int[]
	for i = 1:length(sorted_solns)
        if keep_duplicates
            # is this a duplicate?
            if (i > 1) && (sorted_solns[i].objs == sorted_solns[ids_pareto[end]].objs)
                push!(ids_pareto, i)
                continue
            end
        end
		if sorted_solns[i].objs.s > largest_s_seen
			largest_s_seen = sorted_solns[i].objs.s
			push!(ids_pareto, i)
		end
	end
	return sorted_solns[ids_pareto]
end

"""
	nondominated(soln, solns) # true or false

a point p in a finite set of points S is said to be non-dominated if there is no other point q in S whose coordinates are all greater than or equal to the corresponding coordinates of p. 

BUT we modify so that we consider that solutions with equal objectives are nondominated.
"""
function nondominated(soln::Soln, solns::Vector{Soln})
    for other_soln in solns
		# if they are the same, don't compare.
		if other_soln.objs == soln.objs
			continue
		end
        Δr = other_soln.objs.r - soln.objs.r
        Δs = other_soln.objs.s - soln.objs.s
        if (Δr ≥ 0.0) && (Δs ≥ 0.0)
            return false
        end
    end
    return true
end

"""
    area_indicator(pareto_solns)

compute area indicator, with reference point = the origin, characterizing the quality of a pareto set of solutions.
"""
function area_indicator(pareto_solns::Vector{Soln})
    @assert all([nondominated(p, pareto_solns) for p in pareto_solns])

	# important to only have the unique ones to avoid inflating the area.
    pareto_solns = unique_solns(pareto_solns, :objs)
	 # sort by first objective, 𝔼[reward].
    sort_by_r!(pareto_solns)

	# imagine r on the x-axis and s on the y-axis.
    # initialize area as area of first box
    area = pareto_solns[1].objs.s * pareto_solns[1].objs.r
    # i = index of the box.
    for i = 2:length(pareto_solns) # i = the box
        Δr = pareto_solns[i].objs.r - pareto_solns[i-1].objs.r
        area += pareto_solns[i].objs.s * Δr
        @assert Δr > 0
        @assert pareto_solns[i].objs.s < pareto_solns[i-1].objs.s
    end
    return area
end

#=
visualization of the Pareto set
=#
function _viz_objectives!(ax, solns::Vector{Soln})
	scatter!(ax,
		[soln.objs.r for soln in solns],
		[soln.objs.s for soln in solns]
	)
end

function _viz_area_indicator!(ax, _pareto_solns::Vector{Soln})
    pareto_solns = sort_by_r(_pareto_solns)
	linecolor = "gray"
	shadecolor = ("yellow", 0.2)
	for i = 1:length(pareto_solns)-1
		# vertical line
		lines!(ax,
			[pareto_solns[i].objs.r, pareto_solns[i].objs.r],
			[pareto_solns[i].objs.s, pareto_solns[i+1].objs.s],
			color=linecolor
		)
		# horizontal line
		lines!(ax,
			[pareto_solns[i].objs.r, pareto_solns[i+1].objs.r],
			[pareto_solns[i+1].objs.s, pareto_solns[i+1].objs.s],
			color=linecolor
		)
		# shade
		fill_between!(ax,
			[pareto_solns[i].objs.r, pareto_solns[i+1].objs.r],
			zeros(2),
			[pareto_solns[i+1].objs.s, pareto_solns[i+1].objs.s],
			color=shadecolor
		)
	end
	# first horizontal line
	lines!(ax,
		[0, pareto_solns[1].objs.r],
		[pareto_solns[1].objs.s, pareto_solns[1].objs.s],
		color=linecolor
	)
	# first shade
	fill_between!(ax,
		[0, pareto_solns[1].objs.r],
		zeros(2),
		[pareto_solns[1].objs.s, pareto_solns[1].objs.s],
		color=shadecolor
	)
	# last vertical line
	lines!(ax,
		[pareto_solns[end].objs.r, pareto_solns[end].objs.r],
		[pareto_solns[end].objs.s, 0.0],
		color=linecolor
	)
end

"""
    viz_Pareto_front(solns)
"""
function viz_Pareto_front(solns::Vector{Soln})
	fig = Figure(resolution=the_resolution)
	ax = Axis(
		fig[1, 1],
		xlabel="𝔼(rewards)",
		ylabel="𝔼(# robots survive)"
	)
	xlims!(0, nothing)
	ylims!(0, nothing)
	_viz_objectives!(ax, solns)
	pareto_solns = get_pareto_solns(solns, false)
	_viz_area_indicator!(ax, pareto_solns)
	_viz_objectives!(ax, pareto_solns)
	fig
end
