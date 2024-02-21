#This file defines which  types of variable information and types are supported and and how.

#Get number of variables
MOI.get(model::Optimizer, ::MOI.NumberOfVariables) = length(model.inner.variable_info)
function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    return VI.(1:length(model.inner.variable_info))
end

function MOI.add_variables(model::Optimizer, nvars::Integer)
    return [MOI.add_variable(model) for i = 1:nvars]
end

#Declare support for  discrete  and continous variables with bounds
function MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex},
                                 ::Type{MOI.LessThan{Float64}})
    return true
end
function MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex},
                                 ::Type{MOI.GreaterThan{Float64}})
    return true
end
function MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex},
                                 ::Type{MOI.EqualTo{Float64}})
    return true
end
MOI.supports_add_constrained_variable(model::Optimizer,
set::MOI.Reals) = true
MOI.supports_add_constrained_variable(model::Optimizer,
set::MOI.Interval) = true
MOI.supports_add_constrained_variable(model::Optimizer,
set::MOI.Integer) = true

MOI.supports_add_constrained_variable(model::Optimizer,
set::MOI.ZeroOne) = true

#Implement how "unbounded" variables can be added
function MOI.add_variable(model::Optimizer)
    return MOI.add_constrained_variable(model, MOI.Interval(-10e8, 10e8))[1]
end

# function MOI.add_variables(model::Optimizer, nvars::Integer)
#     return [MOI.add_variable(model) for i in 1:nvars]
# end

#Implement how constrained variables are added to the model
function MOI.add_constrained_variable(model::Optimizer,
                                      set::MOI.Interval)
    var = VariableInfo(set.lower, set.upper, :Cont, nothing, nothing)
    push!(model.inner.variable_info, var)
    #TODO: The interface expects us to return an index for the constraints (but we dont keep track of constraint indices).
    #CI(...) needs be changed if this were to be implemented.

    return VI(length(model.inner.variable_info)),
           MOI.ConstraintIndex{MOI.VariableIndex,MOI.Interval{Float64}}(length(model.inner.variable_info))
end

#Implement adding integer variables
function MOI.add_constrained_variable(model::Optimizer,
                                      set::MOI.Integer)
    var = VariableInfo(-1e6, 1e6, :Int, nothing, nothing)
    push!(model.inner.variable_info, var)
    return VI(length(model.inner.variable_info)),
           MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer}(length(model.inner.variable_info))
end

##Implement adding binary variables
function MOI.add_constrained_variable(model::Optimizer,
                                      set::MOI.ZeroOne)
    var = VariableInfo(0, 1, :Bin, nothing, nothing)
    push!(model.inner.variable_info, var)
    return VI(length(model.inner.variable_info)),
           MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(length(model.inner.variable_info))
end

#Implement variables that are implicitly bounded, because the occur in an inequality constraint only containing them
function MOI.add_constraint(model::Optimizer, v::MOI.VariableIndex,
                            lt::MOI.LessThan{Float64})
    vi = v
    if isnan(lt.upper)
        error("Invalid upper bound value $(lt.upper).")
    end
    model.inner.variable_info[vi.value].upper_bound = min(model.inner.variable_info[vi.value].upper_bound,
                                                          lt.upper)
    if (model.inner.variable_info[vi.value].category == :Bin)
        #Bin can not have bounds
        model.inner.variable_info[vi.value].category = :Int
    end

    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}}(vi.value)
end

#Implement variables that are implicitly bounded, because the occur in an inequality constraint only containing them
function MOI.add_constraint(model::Optimizer, v::MOI.VariableIndex,
                            gt::MOI.GreaterThan{Float64})
    vi = v
    if isnan(gt.lower)
        error("Invalid lower bound value $(gt.lower).")
    end

    model.inner.variable_info[vi.value].lower_bound = max(model.inner.variable_info[vi.value].lower_bound,
                                                          gt.lower)
    if (model.inner.variable_info[vi.value].category == :Bin)
        #Bin can not have bounds
        model.inner.variable_info[vi.value].category = :Int
    end

    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.GreaterThan{Float64}}(vi.value)
end

function MOI.add_constraint(model::Optimizer, v::MOI.VariableIndex,
                            eq::MOI.EqualTo{Float64})
    vi = v
    if isnan(eq.value)
        error("Invalid lower bound value $(eq.value).")
    end

    model.inner.variable_info[vi.value].lower_bound = max(model.inner.variable_info[vi.value].lower_bound,
                                                          eq.value)
    model.inner.variable_info[vi.value].upper_bound = min(model.inner.variable_info[vi.value].upper_bound,
                                                          eq.value)
    if (model.inner.variable_info[vi.value].category == :Bin)
        #Bin can not have bounds
        model.inner.variable_info[vi.value].category = :Int
    end

    return MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo{Float64}}(vi.value)
end

#Declare support for setting names
#MOI.supports(model::Optimizer, ::MOI.VariableName, ::Type{VI}) = true

#Implement  setting variable names
function MOI.set(model::Optimizer, ::MOI.VariableName, vi::VI, name::String)
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value].name = name
end

#Implement  getting variable names
function MOI.get(model::Optimizer, ::MOI.VariableName, vi::VI)::String
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value].name
end

function MOI.set(model::Optimizer, attr::MOI.VariableName, vi::VI, value)
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value].name = value
end

#Declare support for setting  and getting primal start values
function MOI.supports(::Optimizer, ::MOI.VariablePrimalStart,
                      ::Type{MOI.VariableIndex})
    return true
end

function MOI.set(model::Optimizer, ::MOI.VariablePrimalStart,
                 vi::MOI.VariableIndex, value::Union{Real,Nothing})
    model.inner.variable_info[vi.value].start = value

    return
end

function MOI.get(model::Optimizer, ::MOI.VariablePrimalStart, vi::VI)
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value].start
end
