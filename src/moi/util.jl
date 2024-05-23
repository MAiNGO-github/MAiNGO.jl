
function to_expr(f::MOI.ScalarAffineFunction)
    f = MOI.Utilities.canonical(f)
    if isempty(f.terms)
        return f.constant
    end
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.terms
        if iszero(term.coefficient)
            continue
        elseif isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    if length(expr.args) == 2
        return expr.args[end]
    end
    return expr
end

function to_expr(f::MOI.ScalarQuadraticFunction)
    f = MOI.Utilities.canonical(f)
    expr = Expr(:call, :+)
    if !iszero(f.constant)
        push!(expr.args, f.constant)
    end
    for term in f.affine_terms
        if iszero(term.coefficient)
            continue
        elseif isone(term.coefficient)
            push!(expr.args, :(x[$(term.variable.value)]))
        else
            push!(expr.args, :($(term.coefficient) * x[$(term.variable.value)]))
        end
    end
    for term in f.quadratic_terms
        i, j = term.variable_1.value, term.variable_2.value
        coef = (i == j ? 0.5 : 1.0) * term.coefficient
        if iszero(coef)
            continue
        elseif isone(coef)
            push!(expr.args, :(x[$i] * x[$j]))
        else
            push!(expr.args, :($coef * x[$i] * x[$j]))
        end
    end
    if length(expr.args) == 1
        return f.constant
    elseif length(expr.args) == 2
        return expr.args[end]
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
function check_variable_indices(model::Optimizer, index::VI)
    @assert 1 <= index.value <= length(model.inner.variable_info)
end

function check_variable_indices(model::Optimizer, f::SAF)
    for term in f.terms
        check_variable_indices(model, term.variable)
    end
end

function check_variable_indices(model::Optimizer, f::SQF)
    for term in f.affine_terms
        check_variable_indices(model, term.variable)
    end
    for term in f.quadratic_terms
        check_variable_indices(model, term.variable_1)
        check_variable_indices(model, term.variable_2)
    end
end

#How to safely access variable info data.
function find_variable_info(model::Optimizer, vi::VI)
    check_variable_indices(model, vi)
    return model.inner.variable_info[vi.value]
end
