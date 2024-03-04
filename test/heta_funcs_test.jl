@test piecewise(1, true, 2, false, 3, false, 100) === 1
@test piecewise(1, false, 2, true, 3, false, 100) === 2
@test piecewise(1, true, 100) === 1
@test piecewise(1, false, 100) === 100
@test piecewise(1, false) === NaN
@test piecewise(100) == 100
@test piecewise() === NaN