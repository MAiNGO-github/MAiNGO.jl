#This file defines which type of objective function can be handeled, including the optimization sense.

#Supports minimizing or maximizing
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    model.inner.objective_info
    if sense == MOI.MIN_SENSE
        model.inner.objective_info.sense = :Min
    elseif sense == MOI.MAX_SENSE
        model.inner.objective_info.sense = :Max
    elseif sense == MOI.FEASIBILITY_SENSE
        model.inner.objective_info.sense = :Feasibility
    else
        error("Unsupported objective sense: $sense")
    end
    return
end
function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
    if model.inner.objective_info.sense == :Min
        return MOI.MIN_SENSE
    elseif model.inner.objective_info.sense == :Max
        return MOI.MAX_SENSE
    else
        return MOI.FEASIBILITY_SENSE
    end
end

#Declare support for linear and quadratic objective functions. Nonlinear objective function is enabled in constraints.jl
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SAF}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SQF}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SNF}) = true

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction{F},
    obj::F,
) where {F<:Union{SAF,SQF,SNF}}
    model.inner.objective_info.expression = to_expr(obj)
    return
end
