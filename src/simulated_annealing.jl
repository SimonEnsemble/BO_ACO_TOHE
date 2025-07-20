# try trail modification (u, w) -> (u, v, u, w)
function _attempt_node_grab!(robot::Robot, top::TOP)
    # after wut node to insert?
    i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    
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

    # rewire!
    insert!(robot.trail, i+1, v)
    insert!(robot.trail, i+2, u)
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, u] = true

    return true
end

# try trail modification (u, w) -> (u, v, w)
function _attempt_node_insertion!(robot::Robot, top::TOP)
    # after wut node to insert?
    i = rand(1:(length(robot.trail)-2)) # first, last, second-to-last are depot
    
    # proposal: (u, w) -> (u, v, w)
    u = robot.trail[i]
    w = robot.trail[i+1]

    candidate_vs = Int[]
    for v = 2:top.nb_nodes
        if has_edge(top.g, u, v) && has_edge(top.g, v, w) && (! robot.edge_visit[u, v]) && (! robot.edge_visit[v, w])
            push!(candidate_vs, v)
        end
    end

    if length(candidate_vs) == 0
        return false
    end

    # pick a node to insert
    v = rand(candidate_vs)

    # rewire!
    insert!(robot.trail, i+1, v)
    robot.edge_visit[u, w] = false # turn off old edge
    robot.edge_visit[u, v] = true
    robot.edge_visit[v, w] = true

    return true
end

function perturb_trail(
    robot::Robot, top::TOP
)
    # create copy of trail (will not necessarily accept perturbation)
    new_trail = deepcopy(robot.trail)
    @assert robot.done
    @assert new_trail[1] == new_trail[end] == new_trail[end-1] == 1
    
    # current number of non-depot-node visits
    n = length(robot.trail) - 3 # 3 are 1's cuz complete trail

    # candidate perturbations
    if n == 0 # currently staying at depot node
        trail_perturbations = [:insert]
    elseif n == 1 # can't swap or reverse a subsequence
        trail_perturbations = [:insert, :delete, :substitute]
    else
        trail_perturbations = [:swap, :insert, :delete, :substitute, :rev_subseq]
    end
    
    perturbation = sample(trail_perturbations)
    perturbation = :insert
    
    if perturbation == :insert
    elseif perturbation == :swap
        # sample two non-depot nodes to swap
        i, j = sample(2:(n+1), 2, replace=false) # positions
        u, v = new_trail[i], new_trail[j]    # actual node IDs

        # swap
        new_trail[i] = v
        new_trail[j] = u
    elseif perturbation == :delete
        i = rand(2:(n+1))
        deleteat!(new_trail, i)
    elseif perturbation == :substitute
        # choose node to substitute
        unvisited_nodes = get_unvisited_nodes(new_trail, nv(top.g))
        if length(unvisited_nodes) == 0
            return perturb_trail(robot, top)
        end
        v = rand(unvisited_nodes)
        
        # node index to eliminate
        i = rand(2:(n+1))

        # substitute
        new_trail[i] = v
    elseif perturbation == :rev_subseq
        i, j = sample(2:(n+1), 2, replace=false) # positions
        ids = (j > i) ? (i:j) : (j:i)
        new_trail[ids] = reverse(new_trail[ids])
    end
    
    @assert new_trail != robot.trail

    new_robot = Robot(new_trail, top)

    if ! proper_trail(new_robot)
        return perturb_trail(robot, top)
    end
    return new_robot
end
