# functions to perform Global Sensitivity Anlaysis

struct GSAResult
  output_names::Vector{Symbol}
  parameters_names::Vector{Symbol}
  pearson::Matrix{Float64}
  partial::Matrix{Float64}
  standard::Matrix{Float64}
end

parameters(gsar::GSAResult) = gsar.parameters_names
output(gsar::GSAResult) = gsar.output_names
pearson(gsar::GSAResult) = gsar.pearson
partial(gsar::GSAResult) = gsar.partial
standard(gsar::GSAResult) = gsar.standard

function DataFrames.DataFrame(gsar::GSAResult, coef::Symbol)
  if coef == :pearson
    mat = pearson(gsar)
  elseif coef == :partial
    mat = partial(gsar)
  elseif coef == :standard
    mat = standard(gsar)
  else
    throw("Coeffitient type $coef not supported.")
  end
  df = DataFrame(mat, output(gsar))
  insertcols!(df, 1, :parameter => parameters(gsar))
  return df
end

"""
    gsa(mcr::MCResult, timepoint::Number)

Computes Pearson Correlation Coeffitients, Partial Regression Coeffietients and Standard Regression Coeffitients for 
parameters vector and output at a given timepoint

Arguments:

- `mcr`: Monte-Carlo results of type `MCResult`
- `timepoint`: Time to compute coeffitients at 
"""
function gsa(mcr::MCResult, timepoint::Number)
  
  params = parameters(mcr)
  params_mat = Vector(VectorOfArray(LVector.(parameters(mcr))))'
  outvals_mat = Vector(VectorOfArray([mcr[i](timepoint) for i in 1:length(mcr)]))'

  output_names = observables(mcr)
  parameters_names = collect(keys(params[1]))

  pearson = _calculate_correlation_matrix(outvals_mat, params_mat)
  partial = _calculate_partial_correlation_coefficients(outvals_mat, params_mat)
  standard = _calculate_standard_regression_coefficients(outvals_mat, params_mat)

  return GSAResult(output_names, parameters_names, pearson, partial, standard)
end


# the following code was coppied from 
# https://github.com/SciML/GlobalSensitivity.jl/blob/master/src/regression_sensitivity.jl

function _calculate_standard_regression_coefficients(X, Y)
  β̂ = X' \ Y'
  srcs = (β̂ .* std(X, dims = 2) ./ std(Y, dims = 2)')
  return Matrix(transpose(srcs))
end

function _calculate_correlation_matrix(X, Y)
  corr = cov(X, Y, dims = 2) ./ (std(X, dims = 2) .* std(Y, dims = 2)')
  return Matrix(transpose(corr))
end

function _calculate_partial_correlation_coefficients(X, Y)
  XY = vcat(X, Y)
  corr = cov(XY, dims = 2) ./ (std(XY, dims = 2) .* std(XY, dims = 2)')
  prec = pinv(corr) # precision matrix
  pcc_XY = -prec ./ sqrt.(diag(prec) .* diag(prec)')
  # return partial correlation matrix relating f: X -> Y model values
  return Matrix(transpose(pcc_XY[axes(X, 1), lastindex(X, 1) .+ axes(Y, 1)]))
end