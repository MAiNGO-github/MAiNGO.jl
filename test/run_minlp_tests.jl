using MINLPTests: MINLPTests
using Test
using MAiNGO
using MathOptInterface

const MOI = MathOptInterface
const MOIU = MOI.Utilities

const TERMINATION_TARGET_GLOBAL = Dict(
    MINLPTests.FEASIBLE_PROBLEM => MAiNGO.MOI.OPTIMAL,
    MINLPTests.INFEASIBLE_PROBLEM => MAiNGO.MOI.INFEASIBLE,
)
const PRIMAL_TARGET_GLOBAL = Dict(
    MINLPTests.FEASIBLE_PROBLEM => MAiNGO.MOI.FEASIBLE_POINT,
    MINLPTests.INFEASIBLE_PROBLEM => MAiNGO.MOI.NO_SOLUTION,
)

# Exclusions:
# nlp/001_010 002_010 008_010 008_011 009_010 009_011: domain unbounded, 002_010 even negative log
# nlp/005_010     : inv with possible zero in range 
# nlp/005_011     : Using division
# nlp-cvx/109_010 : Even Ipopt fails to converge
# nlp-cvx/105_01x : log with possible negative value in range
# nlp-cvx/204_010 : inv with possible zero in range
# nlp-cvx/205_010 : inv with possible zero in range
# nlp-mi/001_010 002_010: domain unbounded
# nlp-mi/005_010  : inv with possible zero in range 
# nlp-mi/006_010  : user defined function
config = Dict(
    "tol" => 1e-2,
    "dual_tol" => NaN,
    "nlp_exclude" => [
        "001_010",
        "002_010",
        "005_010",
        "005_011",
        "006_010",
        "008_010",
        "008_011",
        "009_010",
        "009_011",
    ],
    "nlpcvx_exclude" => [
        "109_010",
        "105_010",
        "105_011",
        "105_012",
        "105_013",
        "204_010",
        "205_010",
    ],
    "nlpmi_exclude" => ["001_010", "002_010", "005_010", "006_010"],
)

const OPTIMIZER =
    () -> MOI.instantiate(
        MOI.OptimizerWithAttributes(
            () -> MAiNGO.Optimizer(epsilonA = 20.5, epsilonR = 0.5),
            MOI.Silent() => true,
        ),
    )

@testset "NLP" begin
    MINLPTests.test_nlp(
        OPTIMIZER,
        exclude = config["nlp_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
    MINLPTests.test_nlp_expr(
        OPTIMIZER,
        exclude = config["nlp_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
end
@testset "NLP-CVX" begin
    MINLPTests.test_nlp_cvx(
        OPTIMIZER,
        exclude = config["nlpcvx_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
    MINLPTests.test_nlp_cvx_expr(
        OPTIMIZER,
        exclude = config["nlpcvx_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
end
@testset "NLP-MI" begin
    MINLPTests.test_nlp_mi(
        OPTIMIZER,
        exclude = config["nlpmi_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
    MINLPTests.test_nlp_mi_expr(
        OPTIMIZER,
        exclude = config["nlpmi_exclude"],
        termination_target = TERMINATION_TARGET_GLOBAL,
        primal_target = PRIMAL_TARGET_GLOBAL,
        objective_tol = config["tol"],
        primal_tol = config["tol"],
        dual_tol = config["dual_tol"],
    )
end
