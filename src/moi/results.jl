#This file handels how the results can be queried. Not all possible return values are implemented.
#See http://www.juliaopt.org/MathOptInterface.jl/stable/apireference/ for all possible results

#Get termination status
function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    solution_info = model.inner.solution_info
    if solution_info === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    solver_status = solution_info.solver_status
    model_status = solution_info.model_status

    if solver_status == NORMAL_COMPLETION
        if model_status == GLOBALLY_OPTIMAL || model_status == BOUND_TARGETS
            return MOI.OPTIMAL
        elseif model_status == INFEASIBLE
            return MOI.INFEASIBLE
        elseif model_status == FEASIBLE_POINT
            return MOI.LOCALLY_SOLVED
        else
            return MOI.OTHER_ERROR
        end
    else
        return MOI.OTHER_ERROR
    end
    #elseif solver_status == INSUFFICIENT_MEMORY_FOR_NODES
    #    return MOI.MEMORY_LIMIT
    #elseif solver_status == ITERATION_LIMIT
    #    return MOI.ITERATION_LIMIT
    #elseif solver_status == TIME_LIMIT
    #    return MOI.TIME_LIMIT
    #elseif solver_status == NUMERICAL_SENSITIVITY
    #    return MOI.NUMERICAL_ERROR
    #elseif solver_status == INSUFFICIENT_MEMORY_FOR_SETUP
    #    return MOI.MEMORY_LIMIT
    #elseif solver_status == RESERVED
    #    return MOI.OTHER_ERROR
    #elseif solver_status == TERMINATED_BY_BARON
    #    return MOI.OTHER_ERROR
    #elseif solver_status == SYNTAX_ERROR
    #    return MOI.INVALID_MODEL
    #elseif solver_status == LICENSING_ERROR
    #    return MOI.OTHER_ERROR
    #elseif solver_status == USER_HEURISTIC_TERMINATION
    #    return MOI.OTHER_LIMIT
    #end

    return error("Unrecognized Maingo status: $solver_status, $model_status")
end

#Get number of results returned.
function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return (model.inner.solution_info.feasible_point === nothing) ? 0 : 1
end

#Get solution status. Is the solution just a feasible point or the global solution?
function MOI.get(model::Optimizer, ::MOI.PrimalStatus)
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        return MOI.NO_SOLUTION

    elseif solution_info.model_status == FEASIBLE_POINT ||
           solution_info.model_status == GLOBALLY_OPTIMAL
        return MOI.FEASIBLE_POINT
    elseif solution_info.model_status == INFEASIBLE
        return MOI.INFEASIBLE_POINT
    else
        return MOI.NO_SOLUTION
    end
end

#Get the objective value
MOI.get(model::Optimizer, ::MOI.ObjectiveValue) = model.inner.solution_info.objective_value

#Get variable values at solution
function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::VI)
    solution_info = model.inner.solution_info
    if solution_info === nothing || solution_info.feasible_point === nothing
        error("VariablePrimal not available.")
    end
    check_variable_indices(model, vi)
    return solution_info.feasible_point[vi.value]
end

#Get lower bound of the objective function
function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    solution_info = model.inner.solution_info
    return solution_info.lower_bound
end

#Get relative gap as defined in MOI
function MOI.get(model::Optimizer, ::MOI.RelativeGap)
    solution_info = model.inner.solution_info
    lower = solution_info.lower_bound
    upper = solution_info.upper_bound
    return (upper - lower) / abs(upper)
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    info = model.inner.solution_info
    return "solver: $(info.solver_status), model: $(info.model_status)"
end

#function MOI.get(model::Optimizer, ::MOI.NodeCount)
#	
#end

#Get solution time
function MOI.get(model::Optimizer, ::MOI.SolveTimeSec)
    solution_info = model.inner.solution_info
    return solution_info.wall_time
end

function MOI.supports(::Optimizer, ::MOI.SolverVersion)
    return false
end
