module MINLP_traced
using MAiNGO
using JuMP, Test


m = Model(optimizer_with_attributes(MAiNGO.Optimizer, "epsilonA"=> 1e-8, "epsilonR" => 0.5e-8, "relNodeTol" => 1e-11))
MOI.set(m, MOI.Silent(), true)
ub = [2, 2, 1]
@variable(m, 0 ≤ x[i = 1:3] ≤ ub[i])
@variable(m, 1 <= z)
@variable(m, 1 <= w)
@variable(m, y[1:3], Bin)

g(x::Vector{<:Any}, y::Vector{<:Any}, w, z) = log(z) + 1.20log(w) - x[3] - 2y[3]
g2(x::Vector{<:Any}, y::Vector{<:Any}, w, z) = 0.8log(z) + 0.96log(w) - 0.8x[3]
function f(x::Vector{<:Any}, y::Vector{<:Any}, w, z)
    return 5y[1] + 6y[2] + 8y[3] + 10x[1] - 7x[3] - 18log(x[2] + 1) - 19.2log(w) + 10
end
@constraints(m, begin
                 z == x[2] + 1
                 w == x[1] - x[2] + 1
                 g2(x, y, w, z) ≥ 0
                 g(x, y, w, z) ≥ -2
                 x[1] + 1 ≥ 0
                 x[1] - x[2] + 1 ≥ 0
                 x[2] ≤ x[1]
                 x[2] ≤ 2y[1]
                 x[1] - x[2] ≤ 2y[2]
                 y[1] + y[2] ≤ 1
             end)

@objective(m, Min, f(x, y, w, z))

optimize!(m)

@testset "MINLP_traced" begin
    @test isapprox(value(x[1]), 1.300975890892825, rtol = 1e-3)
    @test isapprox(value(x[2]), 0.0, rtol = 1e-4, atol = 1e-3)
    @test isapprox(value(x[3]), 1.0, rtol = 1e-3)
    @test isapprox(value(y[1]), 0.0, rtol = 1e-4, atol = 1e-3)
    @test isapprox(value(y[2]), 1.0, rtol = 1e-3)
    @test isapprox(value(y[3]), 0.0, rtol = 1e-4, atol = 1e-3)
    @test isapprox(objective_value(m), 6.00975890893, rtol = 1e-3)
end

end # module
