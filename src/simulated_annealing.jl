# note: [1, 1]
# and [1, x, 1, 1] are annoying cases for insert.

trail_perturbations = [:swap, :insert, :delete, :substitute, :grab, :delete_segment]

# try trail modification (u, w) -> (u, v, u, w)
function _attempt_node_grab!(robot::Robot, top::TOP; verbose::Bool=false)
    # after wut node to insert?
    if robot.trail == [1, 1]
        i = 1
    else
        # 1, x₁, ..., xₙ, 1, 1 length = n + 3
        i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    end
    
    u = robot.trail[i]
    w = robot.trail[i+1]
    
    candidate_vs = Int[]
    for v = 2:top.nb_nodes
        if has_edge(top.g, u, v) && has_edge(top.g, v, u) && (! robot.edge_visit[u, v]) && (! robot.edge_visit[v, u])
            push!(candidate_vs, v)
        end
    end
    
    if length(candidate_vs) == 0
        return false
    end

    # pick a node to insert
    v = rand(candidate_vs)

    if verbose
        println("\tnode grab: ($u, $w) -> ($u, $v, $u, $w)")
    end

    # rewire!
    insert!(robot.trail, i+1, v)
    insert!(robot.trail, i+2, u)
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, u] = true

    return true
end

# try trail modification (u, w) -> (u, v, w)
function _attempt_node_insertion!(robot::Robot, top::TOP; verbose::Bool=false)
    # after wut node to insert?
    if robot.trail == [1, 1]
        i = 1
    else
        # 1, x₁, ..., xₙ, 1, 1 length = n + 3
        i = rand(1:(length(robot.trail)-1)) # allow insertion after first 1 at end.
    end
    
    # proposal: (u, w) -> (u, v, w)
    u = robot.trail[i]
    w = robot.trail[i+1]

    candidate_vs = Int[]
    for v = 2:top.nb_nodes
        if has_edge(top.g, u, v) && has_edge(top.g, v, w) && (! robot.edge_visit[u, v]) && (! robot.edge_visit[v, w])
            push!(candidate_vs, v)
        end
    end
    
    # no nodes left to insert?
    if length(candidate_vs) == 0
        return false
    end

    # pick a node to insert
    v = rand(candidate_vs)
    
    if verbose
        println("\tinsertion: ($u, $w) -> ($u, $v, $w)")
    end

    # rewire!
    insert!(robot.trail, i+1, v)
    robot.edge_visit[u, w] = false # turn off old edge
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, w] = true
    
    # (1, 1) --> (1, v, 1)
    #   or
    # (1, ..., 1, 1) --> (1, ..., 1, v, 1)
    # ...need 1, 1 at end to signal completion
    if u == w == 1
        push!(robot.trail, 1)
        robot.edge_visit[1, 1] = true
    end

    return true
end

# try trail modification (u, v, w) -> (u, w) i.e. delete v
function _attempt_node_deletion!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a deletion?
    if length(robot.trail) == 2
        return false
    end

    # wut node to delete?
    i = rand(2:(length(robot.trail)-2)) # first, last, second-to-last are depot
    v = robot.trail[i]

    # proposal: (u, v, w) -> (u, w)
    u = robot.trail[i-1]
    w = robot.trail[i+1]

    if u == w
        # def can delete v.
        robot.edge_visit[u, v] = false # turn off old edge
        robot.edge_visit[v, w] = false # turn off old edge
        
        deleteat!(robot.trail, i)
        deleteat!(robot.trail, i) # (u, v, u) -> (u)
        return true
    end

    if (! has_edge(top.g, u, w)) || robot.edge_visit[u, w]
        return false
    end

    if verbose
        println("\tdeletion: ($u, $v, $w) -> ($u, $w)")
    end

    # rewire!
    deleteat!(robot.trail, i)
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, w] = true

    return true
end

# try trail modification (u, v, w) -> (u, x, w)
function _attempt_node_substitution!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a substitution?
    if length(robot.trail) ≤ 3
        return false
    end

    # wut node to subs for another?
    i = rand(2:(length(robot.trail)-2)) # first, last, second-to-last are depot
    v = robot.trail[i]

    u = robot.trail[i-1]
    w = robot.trail[i+1]
    
    candidate_xs = Int[]
    for x = 2:top.nb_nodes
        if has_edge(top.g, u, x) && has_edge(top.g, x, w) && (! robot.edge_visit[u, x]) && (! robot.edge_visit[x, w])
            push!(candidate_xs, x)
        end
    end

    if length(candidate_xs) == 0
        return false
    end

    x = rand(candidate_xs)

    if verbose
        println("\tnode subs ($u, $v, $w) -> ($u, $x, $w)")
    end
    
    robot.trail[i] = x
    
    # rewire
    robot.edge_visit[u, v] = false # turn off old edge
    robot.edge_visit[v, w] = false # turn off old edge
    robot.edge_visit[u, x] = true
    robot.edge_visit[x, w] = true

    return true
end

# try trail modification (1, ..., u, x₁, ..., xₙ, v, ..., 1, 1) -> (1, u, v, 1, 1)
function _attempt_node_delete_segment!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short?
    if length(robot.trail) ≤ 5
        return false
    end

    # sample two non-depot nodes to delete between (inclusive)
    i, j = sort(sample(2:(length(robot.trail)-2), 2, replace=false)) # positions

    u = robot.trail[i-1]
    v = robot.trail[j+1]

    if (! has_edge(top.g, u, v)) || robot.edge_visit[u, v]
        return false
    end

    if verbose
        println("\tdeleting the ... in the segment ($u, ..., $v)")
    end

    robot.edge_visit[u, v] = true
    for k = (i-1):j
        u′ = robot.trail[k]
        v′ = robot.trail[k+1]
        robot.edge_visit[u′, v′] = false
    end
    robot.trail = vcat(robot.trail[1:i-1], robot.trail[j+1:end])

    if length(robot.trail) == 3
        robot.trail == [1, 1]
    end
    robot.edge_visit[1, 1] = true # just don't ever turn this off.

    return true
end

# try trail modification (u, v, w) and (x, y, z) -> (u, y, w) and (x, v, z)
function _attempt_node_swap!(robot::Robot, top::TOP; verbose::Bool=false)
    # too short for a swap?
    if length(robot.trail) ≤ 5
        return false
    end

    # sample two non-depot nodes to swap
    i, j = sample(2:(length(robot.trail)-2), 2, replace=false) # positions
    v = robot.trail[i]
    y = robot.trail[j]

    u = robot.trail[i-1]
    w = robot.trail[i+1]
    
    x = robot.trail[j-1]
    z = robot.trail[j+1]

    # is the swap possible?
    for (s, d) in [(u, y), (y, w), (x, v), (v, z)]
        # deal-breaker: no edge in graph or it has been used
        if (! has_edge(top.g, s, d)) || robot.edge_visit[s, d]
            return false
        end
    end
    
    if verbose
        println("\tnode swap ($u, $v, $w) and ($x, $y, $z) -> ($u, $y, $w) and ($x, $v, $z)")
    end

    # swap possible if got here
    robot.trail[i] = y
    robot.trail[j] = v
    
    # rewire (turn off old edges and add new
    robot.edge_visit[u, v] = false
    robot.edge_visit[v, w] = false
    robot.edge_visit[x, y] = false
    robot.edge_visit[y, z] = false
    
    robot.edge_visit[u, y] = true
    robot.edge_visit[y, w] = true
    robot.edge_visit[x, v] = true
    robot.edge_visit[v, z] = true

    return true
end

function perturb_trail(
    robot::Robot, top::TOP; verbose::Bool=false, do_verification::Bool=true
)
    # create copy of trail (will not necessarily accept perturbation)
    @assert robot.done
    new_robot = deepcopy(robot)
    
    # current number of non-depot-node visits
    n = length(robot.trail) - 3 # 3 are 1's cuz complete trail
        

    perturbation = sample(trail_perturbations)
    
    success = false
    if perturbation == :insert
        success = _attempt_node_insertion!(new_robot, top, verbose=verbose)
    elseif perturbation == :grab
        success = _attempt_node_grab!(new_robot, top, verbose=verbose)
    elseif perturbation == :swap
        success = _attempt_node_swap!(new_robot, top, verbose=verbose)
    elseif perturbation == :delete
        success = _attempt_node_deletion!(new_robot, top, verbose=verbose)
    elseif perturbation == :delete_segment
        success = _attempt_node_delete_segment!(new_robot, top, verbose=verbose)
    elseif perturbation == :substitute
        success = _attempt_node_substitution!(new_robot, top, verbose=verbose)
    end

    if ! success
        return perturb_trail(robot, top, verbose=verbose)
    end
   
    if verbose
        println("\tnew trail: ", new_robot.trail)
    end
    if do_verification
        verify(new_robot, top)
    end

    return new_robot, perturbation
end

function so_simulated_annealing(
    # the team orienteering problem
    top::TOP,
    # weight on reward objective
    wᵣ::Float64,
    # number of iterations
    nb_iters::Int;
    verbose::Bool=false,
    # cooling schedule
    T₀::Float64=0.5,
    Tₘᵢₙ::Float64=0.005
)
    @assert wᵣ ≤ 1.0 && wᵣ ≥ 0.0
    if verbose
        println("weight on reward objective: ", wᵣ)
    end
    
    # start with idle robots
    robots = [Robot([1, 1], top) for k = 1:top.nb_robots]
    new_robots = deepcopy(robots) # cuz won't necessary accept

    # track stuff
    perturbation_counts = Dict(p => 0 for p in MOACOTOP.trail_perturbations)
    agg_objectives = zeros(nb_iters)

    # store best solution
    best_soln = Soln(robots, Objs(NaN, NaN))
    best_obj = -Inf

    # obj normalization factors
    r_ref = sum([get_r(top, v) for v = 1:nv(top.g)])
    s_ref = top.nb_robots

    # track last objective to decide to accept or reject (just accept first)
    old_obj = -Inf

    for i = 1:nb_iters
        # generate a candidate solution by perturbing current solution
        # ... so it's a neighbor solution
        for k = 1:top.nb_robots
            new_robots[k], perturbation = perturb_trail(robots[k], top)
            perturbation_counts[perturbation] += 1
        end
        
        # compute two objectives with these robot paths
        #   normalize so temperature makes sense
        new_objs = Objs(
            𝔼_reward(new_robots, top),
            𝔼_nb_robots_survive(new_robots, top)
        )
    
        # compute aggregated objective
        new_obj = wᵣ * new_objs.r / r_ref + (1 - wᵣ) * new_objs.s / s_ref

        # track global best solution
        if new_obj > best_obj
            best_soln = Soln(deepcopy(new_robots), new_objs)
            best_obj = new_obj
        end

        # temperature
        T = max(T₀ - (i - 1) / nb_iters, Tₘᵢₙ)

        if verbose
            println("iteration ", i)
            println("\ttemperature: ", round(T, digits=3))
            println("\tcurrent objective: ", round(old_obj, digits=3))
            println("\taggregated new objective: ", round(new_obj, digits=3))
            println("\t\tbest objective so far: ", round(best_obj, digits=3))
        end

        # decide to accept or reject
        Δ_obj = new_obj - old_obj
        if Δ_obj > 0.0 # improved solution!
            # accept
            robots = deepcopy(new_robots)
            old_obj = new_obj
            if verbose
                println("\t\taccepting better solution.")
            end
        else # worse solution
            p_accept = exp(Δ_obj / T)
            if rand() < p_accept
                robots = deepcopy(new_robots)
                old_obj = new_obj
                if verbose
                    println(
                        "\t\taccepting worse soln w. prob $(round(p_accept, digits=2))."
                    )
                end
            else
                if verbose
                    println("\t\trejecting worse solution w. prob $(round(1-p_accept, digits=2)).")
                end
            end
        end

        agg_objectives[i] = old_obj
    end
    return best_soln, agg_objectives, perturbation_counts
end
