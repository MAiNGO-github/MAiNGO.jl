module BadExpressions
using MAiNGO
using JuMP, Test

@testset "UnrecognizedExpressionException" begin
    exception =
        MAiNGO.UnrecognizedExpressionException("comparison", :(sinh(x[1])))
    buf = IOBuffer()
    Base.showerror(buf, exception)
    @test occursin("sinh(x[1])", String(take!(buf)))
end

@testset "Sinh unrecognized" begin
    model = Model((MAiNGO.Optimizer))
    @variable model x
    @NLconstraint model sinh(x) == 0
    @test_throws MAiNGO.UnrecognizedExpressionException optimize!(model) # FIXME: currently broken due to lack of NLPBlock support.
end

end # module
