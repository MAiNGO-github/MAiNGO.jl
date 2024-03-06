module NLP2

using JuMP, Test
using MAiNGO

m = Model(MAiNGO.Optimizer)
MOI.set(m, MOI.Silent(), true)
ub = [9.422, 5.9023, 267.417085245]
@variable(m, 0 ≤ x[i = 1:3] ≤ ub[i])

@constraints(m, begin
                 250 + 30x[1] - 6x[1]^2 == x[3]
                 300 + 20x[2] - 12x[2]^2 == x[3]
                 150 + 0.5 * (x[1] + x[2])^2 == x[3]
             end)

@objective(m, Min, -x[3])

optimize!(m)

@testset "NLP2" begin
    @test isapprox(value(x[1]), 6.2934300, rtol = 1e-6)
    @test isapprox(value(x[2]), 3.8218391, rtol = 1e-6)
    @test isapprox(value(x[3]), 201.1593341, rtol = 1e-5)
    @test isapprox(objective_value(m), -201.1593341, rtol = 1e-6)
end
end # module
