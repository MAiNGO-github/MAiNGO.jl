#This file handels support for constraints. Defines what type of constraints can be handeled.

#Declare and implement support for scalar affine and quadratic constraints
function MOI.supports_constraint(::Optimizer,
                                 ::Type{<:Union{MOI.ScalarAffineFunction{Float64},
                                                MOI.ScalarQuadraticFunction{Float64},
                                                MOI.ScalarNonlinearFunction}},
                                 ::Type{<:Union{MOI.GreaterThan{Float64},
                                                MOI.LessThan{Float64},MOI.EqualTo{Float64}}})
    return true
end

#How a linear or quadratic constraint can be added.
#Linear and quadratic constraints are converted into nonlinear constraints.
function MOI.add_constraint(model::Optimizer,
                            f::Union{MOI.ScalarAffineFunction{Float64},
                                     MOI.ScalarQuadraticFunction{Float64},
                                     MOI.ScalarNonlinearFunction},
                            set::Union{MOI.GreaterThan{Float64},MOI.LessThan{Float64},
                                       MOI.EqualTo{Float64}})
    #check_variable_indices(model, f)

    expr = to_expr(f)
    if (isa(set, MOI.EqualTo))
        expr = :($expr == $(set.value))
    elseif (isa(set, MOI.LessThan) || set.lower === nothing)
        expr = :($expr <= $(set.upper))
    elseif (isa(set, MOI.GreaterThan) || set.upper === nothing)
        expr = :($(set.lower) <= $expr)
    else
        expr = :($(set.lower) <= $expr <= $(set.upper))
    end
    push!(model.inner.constraint_info, ConstraintInfo(expr, nothing))
    return MOI.ConstraintIndex{typeof(f),typeof(set)}(length(model.inner.constraint_info))
end

##Declare and implement support for setting and getting constraint names
MOI.supports(model::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex}) = true
function MOI.get(model::Optimizer, ::MOI.ConstraintName, ci::MOI.ConstraintIndex)::String
    println(model.inner.constraint_info[ci.value].name)
    return model.inner.constraint_info[ci.value].name
end

function MOI.set(model::Optimizer, ::MOI.ConstraintName, ci::MOI.ConstraintIndex,
                 name::String)
    model.inner.constraint_info[ci.value].name = name
    return nothing
end

function MOI.get(model::Optimizer, ::Type{MOI.ConstraintIndex}, name::String)
    for (i, c) in enumerate(model.inner.constraint_info)
        if name == c.name
            return MOI.ConstraintIndex(i)
        end
    end
    return error("Unrecognized constraint name $name.")
end

##Declare and implement support for setting nonlinear constraints
MOI.supports(::Optimizer, ::MOI.NLPBlock) = true

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_data::MOI.NLPBlockData)
    model.nlp_block_data = nlp_data
    nlp_eval = nlp_data.evaluator
    MOI.initialize(nlp_eval, [:ExprGraph])

    for i = 1:length(nlp_data.constraint_bounds)
        expr = MOI.constraint_expr(nlp_eval, i)
        constraint_info = ConstraintInfo(expr, nothing)
        push!(model.inner.constraint_info, constraint_info)
    end
    if (nlp_data.has_objective)
        expr = MOI.objective_expr(nlp_eval)
        model.inner.objective_info = ObjectiveInfo(expr, model.inner.objective_info.sense)
    end
    return nothing
end

## Allow setting binary after creation
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Integer}) = true

function MOI.add_constraint(model::Optimizer, f::MOI.VariableIndex,
                            set::Union{MOI.ZeroOne,MOI.Integer})
    vi = f
    check_variable_indices(model, vi)
    variable_info = model.inner.variable_info[vi.value]
    if set isa MOI.ZeroOne
        variable_info.category = :Bin
        model.inner.variable_info[vi.value].upper_bound = min(model.inner.variable_info[vi.value].upper_bound,
                                                              1.0)
        model.inner.variable_info[vi.value].lower_bound = max(model.inner.variable_info[vi.value].lower_bound,
                                                              0.0)

        if (model.inner.variable_info[vi.value].upper_bound != 1.0)
            #Bin can not have bounds
            model.inner.variable_info[vi.value].category = :Int
        end
        if (model.inner.variable_info[vi.value].lower_bound != 0.0)
            #Bin can not have bounds
            model.inner.variable_info[vi.value].category = :Int
        end

    elseif set isa MOI.Integer
        variable_info.category = :Int
    else
        error()
    end
    return MOI.ConstraintIndex{MOI.VariableIndex,typeof(set)}(vi.value)
end
