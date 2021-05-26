function loss(sim::SimResults, measurements::Vector)
  loss = 0.0
  for dp in measurements
    loss += loss_point(sim, dp)
  end
  return loss
end

function loss_point(sim::SimResults, dp::NormalMeasurementPoint{MU,S}) where {MU,S}
  sim_val = _param_value(sim, dp.μ, dp)
  measurements_val = dp.val
  sigma = _param_value(sim, dp.σ, dp)
  sigma_sq = (sigma)^2

  log(2π) + log(sigma_sq) + (sim_val - measurements_val)^2 / sigma_sq
end

_param_value(sim, p::Float64, dp) = p
 
function _param_value(sim, p::Symbol, dp)
  if p ∈ keys(constants(sim))
    val = constants(sim)[p]
  elseif p ∈ observables(sim)
    val = sim(dp.t, p, dp.scope)
  else 
    error("$p not found in simulated results.")
  end
  return val
end
