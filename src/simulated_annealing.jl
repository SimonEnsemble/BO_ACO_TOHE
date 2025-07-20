function get_unvisited_nodes(trail::Vector{Int}, nb_nodes::Int)
    return [v for v = 1:nb_nodes if ! (v in trail)]
end

function perturb_trail(
    robot::Robot, top::TOP
)
    # create copy of trail (will not necessarily accept perturbation)
    new_trail = deepcopy(robot.trail)
    @assert new_trail[1] == new_trail[end] == new_trail[end-1] == 1
    @assert robot.done
    
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
    
    if perturbation == :insert
        # where to insert?
        i = 1 + rand(1:(n+1)) # 1 b/c first node stays depot

        # list of candidate nodes to insert
        unvisited_nodes = get_unvisited_nodes(new_trail, nv(top.g))

        # pick a node to insert
        new_v =  rand(unvisited_nodes)

        # do it!
        insert!(new_trail, i, new_v)
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
