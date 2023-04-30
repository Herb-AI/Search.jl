"""
Calculates the ratio between the cost of the current program and the cost of the proposed program.
If the functino returns 
- True => new program is accepted 
- False => new program is rejected
# Arguments
- `current_cost::Float`: the cost of the current program.
- `next_cost::Float`: the cost of the proposed program.
- `temperature::Float`: the temperature; not used.
"""
function probabilistic_accept(current_cost, next_cost, temperature)
    ratio = current_cost / (current_cost + next_cost)
    return ratio >= rand()
end

"""
Returns true if the cost of the proposed program is smaller than the cost of the current program.
Otherwise, returns false.
# Arguments
- `current_cost::Float`: the cost of the current program.
- `next_cost::Float`: the cost of the proposed program.
- `temperature::Float`: the temperature; not used.
"""
function best_accept(current_cost, next_cost, temperature)
    return current_cost > next_cost
end

"""
Returns true if the cost of the proposed program is smaller than the cost of the current program.
Otherwise, returns true with the probability equal to: 
```math
1 / (1 + exp(delta / temperature))
```
In any other case, returns false.
# Arguments
- `current_cost::Float`: the cost of the current program.
- `next_cost::Float`: the cost of the proposed program.
- `temperature::Float`: the temperature of the search.
"""
function probabilistic_accept_with_temperature(current_cost, next_cost, temperature)
    delta = next_cost - current_cost
    if delta < 0
        return true
    end
    return 2 / (1 + exp(delta / temperature)) > rand()
end


function probabilistic_accept_with_temperature_fraction(current_cost, program_to_consider_cost, temperature)
    ratio = current_cost / (program_to_consider_cost + current_cost)
    if ratio >= 1
        return true
    end
    return ratio * temperature >= rand()
end