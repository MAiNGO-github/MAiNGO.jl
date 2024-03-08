
#Set lower bounds on constraints or variables
function set_lower_bound(
    info::Union{VariableInfo,ConstraintInfo},
    value::Union{Number,Nothing},
)
    if value !== nothing
        # info.lower_bound !== nothing && throw(ArgumentError("Lower bound has already been set"))
        info.lower_bound = value
    end
    return
end

#Set upper bounds on constraints or variables
function set_upper_bound(
    info::Union{VariableInfo,ConstraintInfo},
    value::Union{Number,Nothing},
)
    if value !== nothing
        # info.upper_bound !== nothing && throw(ArgumentError("Upper bound has already been set"))
        info.upper_bound = value
    end
    return
end

#Set equality constraints on constraints
function set_equal(info::ConstraintInfo, value::Union{Number,Nothing})
    if value !== nothing
        info.upper_bound = value
        info.lower_bound = value
        info.is_equality = true
    end
    return
end

#Define when a model is considered empty
function is_empty(model::MAINGOModel)
    return isempty(model.variable_info) && isempty(model.constraint_info)
end

#Helper function. Parentheses make formulas easier to understand with operator precedence.
wrap_with_parens(x::String) = string("(", x, ")")

#Check if the operations are supported
verify_support(c) = c

function verify_support(c::Symbol)
    if c !== :NaN # blocks NaN and +/-Inf
        return c
    end
    return error("Got NaN in a constraint or objective.")
end

function verify_support(c::Real)
    if isfinite(c) # blocks NaN and +/-Inf
        return c
    end
    return error("Expected number but got $c")
end

function verify_support(c::Expr)
    if c.head == :call
        if c.args[1] in (
            :+,
            :-,
            :*,
            :/,
            :exp,
            :log,
            :abs,
            :min,
            :max,
            :sin,
            :cos,
            :tan,
            :tanh,
        )
            return c
        elseif c.args[1] in (:<=, :>=, :(==))
            map(verify_support, c.args[2:end])
            return c
        elseif c.args[1] == :^
            @assert isa(c.args[2], Real) || isa(c.args[3], Real)
            return c
        else # TODO: do automatic transformation for x^y, |x|
            error("Unsupported expression $c")
        end
    end
    return c
end

struct UnrecognizedExpressionException <: Exception
    exprtype::String
    expr::Any
end
function Base.showerror(io::IO, err::UnrecognizedExpressionException)
    print(io, "UnrecognizedExpressionException: ")
    return print(io, "unrecognized $(err.exprtype) expression: $(err.expr)")
end

#added some code from SCIP.jl/src/nonlinear.jl

# Mapping from Julia (as given by MOI) to strings for unary functions
const UnaryOpMAP = Dict{Symbol,String}(
    :sqrt => "sqrt",    # unary
    :exp => "exp",     # unary
    :log => "log",     # unary
    :abs => "abs",
    :sin => "sin",
    :cos => "cos",
    :tan => "tan",
    :tanh => "tanh",
)
const BinaryOpMAP = Dict{Symbol,String}(
    :min => "min",      # binary
    :max => "max",
)

##This function enables the conversion from the symbolic expressions used in MathOptInterface to the ALE syntax used in MAINGO

#Base case if no expression but symbol
function to_str(x, y = nothing)
    if (x == :(==))
        return "="
    else
        return string(x)
    end
end

#Main function
function to_str(
    expr::Expr,
    variable_names::Union{Nothing,Array{String,1}} = nothing,
)

    #Shorthand to always use the variable names
    to_str_(x) = to_str(x, variable_names)

    num_children = length(expr.args) - 1
    if Meta.isexpr(expr, :comparison) # range constraint
        if length(expr.args) == 5
            # args: [lhs, <=, mid, <=, rhs], lhs and rhs constant
            return join(
                [
                    expr.args[1],
                    expr.args[2],
                    to_str_(expr.args[3]),
                    expr.args[4],
                    expr.args[5],
                ],
                "",
            )
        elseif length(expr.args) == 3
            # args: [op, lhs, rhs] rhs const
            #return join([to_str_(expr.args[1]), expr.args[2], expr.args[3]], "")
            return join([to_str_(expr.args[2]), expr.args[1], expr.args[3]], "")
        else
            throw(UnrecognizedExpressionException("comparison", expr))
        end

    elseif Meta.isexpr(expr, :call) # operator
        op = expr.args[1]
        if op in [:(==), :<=, :>=]
            # args: [op, lhs, rhs]
            if length(expr.args) == 3
                return return join(
                    [
                        to_str_(expr.args[2]),
                        to_str_(expr.args[1]),
                        to_str_(expr.args[3]),
                    ],
                    " ",
                )
                # args: [lhs, <=, mid, <=, rhs]
            elseif length(expr.args) == 5
                return join(
                    [
                        to_str_(expr.args[1]),
                        to_str_(expr.args[2]),
                        to_str_(expr.args[3]),
                        to_str_(expr.args[4]),
                        to_str_(expr.args[5]),
                    ],
                    " ",
                )
            end

        elseif all(d -> isa(d, Real), expr.args[2:end]) # handle case with just numeric values, so compute e.g. exp(-4)
            return wrap_with_parens(string(eval(expr)))
        elseif op == :^
            return join(
                [
                    "pow(",
                    to_str_(expr.args[2]),
                    ",",
                    to_str_(expr.args[3]),
                    ")",
                ],
                " ",
            )

        elseif op == :- && num_children == 1
            # Special case: unary version of minus. 
            return join(["-(", to_str_(expr.args[2]), ")"], " ")

        elseif op in [:sqrt, :exp, :log, :abs, :sin, :cos, :tan, :tanh]
            # Unary operators
            @assert num_children == 1
            return join([UnaryOpMAP[op], "(", to_str_(expr.args[2]), ")"], " ")

        elseif op in (:+, :-, :*, :/)
            # N-ary operations
            return wrap_with_parens(
                string(
                    join(
                        [to_str_(d) for d in expr.args[2:end]],
                        string(expr.args[1]),
                    ),
                ),
            )
        elseif op in [:min, :max]
            # Binary operators
            @assert num_children == 2

            return join(
                [
                    BinaryOpMAP[op],
                    "(",
                    to_str_(expr.args[2]),
                    ",",
                    to_str_(expr.args[3]),
                    ")",
                ],
                " ",
            )

        else
            throw(UnrecognizedExpressionException("call", expr))
        end
    elseif Meta.isexpr(expr, :ref) # variable
        # Referencing a array entry
        # Is done in MathOptInterface for the variables
        # It should look like this:
        # :(x[MathOptInterface.VariableIndex(1)])
        # or if added from affine term
        # : x[1]
        if ((expr.args[1] == :x) && (num_children == 1))
            if (isa(expr.args[2], MOI.VariableIndex))
                varIndex = expr.args[2].value # MOI.VariableIndex instead of simple integer encountered
            else
                varIndex = expr.args[2]       # when added from affine this is only an integer
            end
            if (variable_names === nothing)
                return "x$(varIndex)"         #No variable names known
            else
                return string(variable_names[varIndex])
            end
        else
            throw(UnrecognizedExpressionException("reference", expr))
        end
        #catch boundary case of empty / blank objective
    elseif Meta.isexpr(expr, :tuple)
        return "0"
    elseif expr === nothing
        return "0"
    else
        dump(expr)
        throw(UnrecognizedExpressionException("unknown", expr))
    end
end

#Set names of unnamed variables or constraints
function set_unique_names!(infos, default_base_name::AbstractString)
    names = Set(String[])
    default_name_counter = Ref(1)
    for info in infos
        if info.name === nothing
            base_name = default_base_name
            name_counter = default_name_counter
        elseif info.name ∉ names
            push!(names, info.name)
            continue
        else
            base_name = info.name
            name_counter = Ref(1)
        end
        while true
            name = string(base_name, name_counter[])
            if name ∉ names
                info.name = name
                push!(names, info.name)
                break
            else
                name_counter[] += 1
            end
        end
    end
end

#Formulate the ALE problem. This function converts the  equations and adds additional syntax, e.g., for defining variables.
function write_ALE_problem(m::MAINGOModel)
    fp = IOBuffer()

    # Ensure that all variables and constraints have a name
    set_unique_names!(m.variable_info, "x")
    set_unique_names!(m.constraint_info, "constr")
    variable_names = [i.name for i in m.variable_info]
    #Define variables
    println(fp, "definitions:")
    println(fp)
    idx = 1:length(m.variable_info)
    for i in idx
        if (m.variable_info[i].category == :Bin)
            prefix = "binary "
        elseif (m.variable_info[i].category == :Int)
            prefix = "integer "
        else
            prefix = "real "
        end

        if (m.variable_info[i].category != :Bin)
            postfix =
                " in [" *
                string(m.variable_info[i].lower_bound) *
                "," *
                string(m.variable_info[i].upper_bound) *
                "];"
        else
            postfix = ";"
        end
        println(fp, prefix, m.variable_info[i].name, postfix)
        if (m.variable_info[i].start !== nothing)
            println(
                fp,
                m.variable_info[i].name,
                ".init <-",
                m.variable_info[i].start,
                ";",
            )
        end
    end
    #Declare constraints
    if !isempty(m.constraint_info)
        println(fp)
        println(fp, "constraints:")
        for c in m.constraint_info
            str = to_str(c.expression, variable_names)
            print(fp, str)
            qoutestr = "\""
            println(fp, " ", qoutestr, c.name, qoutestr, ";")
        end
    end
    println(fp)
    println(fp, "objective: #Always minimizing")
    if (
        m.objective_info.sense == :Feasibility ||
        m.objective_info.expression === nothing
    )
        println(fp, "0;")
    elseif (m.objective_info.sense == :Max)
        println(
            fp,
            "-",
            wrap_with_parens(
                to_str(m.objective_info.expression, variable_names),
            ),
            ";",
        )
    elseif (m.objective_info.sense == :Min)
        println(fp, to_str(m.objective_info.expression, variable_names), ";")
    else
        println(fp, "NO OBJ")
    end
    return fp
end

#Write problem from memory to file
function write_ALE_file(m::MAINGOModel)
    open(m.problem_file_name, "w") do fp
        return write(fp, String(take!(write_ALE_problem(m::MAINGOModel))))
    end
end

# required for reading results from json file
using JSON

#Used to read in output files without requiring the C-API
function read_results(m::MAINGOModel, retcode)
    statusMap = Dict(
        "Globally optimal" => GLOBALLY_OPTIMAL,
        "Infeasible" => INFEASIBLE,
        "Feasible point" => FEASIBLE_POINT,
        "No feasible point found" => NO_FEASIBLE_POINT_FOUND,
        "Reached target bound" => BOUND_TARGETS,
        "Not solved yet" => NOT_SOLVED_YET,
        "Just a worker" => JUST_A_WORKER_DONT_ASK_ME,
    )
    m.solution_info = SolutionStatus()
    if retcode == -1
        m.solution_info.solver_status = TERMINATED_BY_MAINGO
        m.solution_info.model_status = NO_FEASIBLE_POINT_FOUND
    elseif retcode > 0
        m.solution_info.solver_status = UNKNOWN_ERROR
        m.solution_info.model_status = NO_FEASIBLE_POINT_FOUND
    else
        if haskey(m.options, "writeJson") && m.options["writeJson"] == 1
            df = JSON.parsefile("statisticsAndSolution.json")
            feasible_solution_found = df["Solution"]["FoundFeasiblePoint"]
            m.solution_info.wall_time = df["Timing"]["TotalWall"]
            m.solution_info.cpu_time = df["Timing"]["TotalCPU"]
            m.solution_info.model_status =
                statusMap[df["Solution"]["MAiNGOstatus"]]
            m.solution_info.solver_status = NORMAL_COMPLETION
            if feasible_solution_found == 1.0
                if m.objective_info.sense == Symbol("Min")
                    m.solution_info.objective_value =
                        df["Solution"]["BestSolutionValue"]
                    m.solution_info.upper_bound =
                        m.solution_info.objective_value
                    m.solution_info.lower_bound =
                        m.solution_info.upper_bound -
                        df["Solution"]["AbsoluteGap"]
                elseif m.objective_info.sense == Symbol("Max")
                    # MAiNGO always formulates minimization problem, so we need to flip the sign and the bounds in case of maximization
                    m.solution_info.objective_value =
                        -df["Solution"]["BestSolutionValue"]
                    m.solution_info.lower_bound =
                        m.solution_info.objective_value
                    m.solution_info.upper_bound =
                        m.solution_info.upper_bound +
                        df["Solution"]["AbsoluteGap"]
                end
                m.solution_info.feasible_point = Float64[]
                for var in df["Solution"]["SolutionPoint"] # assumes ordering is maintained throughout everything, assumption seems justified based on some tests
                    push!(m.solution_info.feasible_point, var["VariableValue"])
                end
            else
                m.solution_info.feasible_point = Nothing
                m.solution_info.objective_value = NaN
                m.solution_info.upper_bound = NaN
                m.solution_info.lower_bound = NaN
            end
        else
            @warn(
                "The model might have solved, but reading results from the standalone version is only possible from json output currently. Please set the option \"writeJson\" to 1."
            )
        end
    end
end

# Write a settings file to be read when using the standalone version
function write_settings_file(model::MAINGOModel)
    model.options["settings_name"] = pwd() * "/MAiNGOSettingsJuMP.txt"
    model.settings_file_name = pwd() * "/MAiNGOSettingsJuMP.txt"
    open("MAiNGOSettingsJuMP.txt", "w") do file
        for (key, value) in model.options
            if (
                !(
                    key in
                    ["prob_name", "res_name", "log_name", "settings_name"]
                ) && isa(value, Real)
            )
                settingstring = key * " " * string(value) * "\n"
                write(file, settingstring)
            end
        end
    end
end
