
#Convert a affine term to symbolic expression
function to_expr(f::MOI.ScalarAffineFunction{Float64})
    f = MOI.Utilities.canonical(f)
    if isempty(f.terms)
        return f.constant
    else
        linear_term_exprs = map(f.terms) do term
            return :($(term.coefficient) * x[$(term.variable.value)])
        end
        expr = :(+($(linear_term_exprs...)))
        if !iszero(f.constant)
            push!(expr.args, f.constant)
        end

        return expr
    end
end

#Convert a quadratic terms to symbolic expression
function to_expr(f::MOI.ScalarQuadraticFunction{Float64})
    f = MOI.Utilities.canonical(f)
    linear_term_exprs = map(f.affine_terms) do term
        i = term.variable.value
        return :($(term.coefficient) * x[$i])
    end
    quadratic_term_exprs = map(f.quadratic_terms) do term
        i = term.variable_1.value
        j = term.variable_2.value
        if i == j
            :($(term.coefficient / 2) * x[$i] * x[$j])
        else
            :($(term.coefficient) * x[$i] * x[$j])
        end
    end
    expr = :(+($(linear_term_exprs...), $(quadratic_term_exprs...)))
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    return expr
end

function to_expr(f::MOI.ScalarNonlinearFunction)
    expr = Expr(:call, f.head)
    for arg in f.args
        push!(expr.args, to_expr(arg))
    end
    return expr
end

to_expr(x::Real) = x

to_expr(vi::MOI.VariableIndex) = :(x[$(vi.value)])

# check_variable_indices
function check_variable_indices(model::Optimizer, index::MOI.VariableIndex)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

function check_variable_indices(model::Optimizer, f::MOI.ScalarAffineFunction{Float64})
    for term in f.terms
        check_variable_indices(model, term.variable)
    end
end

function check_variable_indices(model::Optimizer, f::MOI.ScalarQuadraticFunction{Float64})
    for term in f.affine_terms
        check_variable_indices(model, term.variable)
    end
    for term in f.quadratic_terms
        check_variable_indices(model, term.variable_1)
        check_variable_indices(model, term.variable_2)
    end
end

#How to safely access variable info data.
function find_variable_info(model::Optimizer, vi::MOI.VariableIndex)
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value]
end
