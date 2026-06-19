#=
    This code was generated from DynMS JSON by HetaImporter 0.1.0
=#

(function()

### MODEL nameless ###

### create default constants
nameless_constants_num_ = NamedTuple{(:k1,)}((0.01,))

### create static ids
nameless_statics_id_ = (:comp1,)

### create default observables
nameless_records_output_ = NamedTuple{(:comp1, :B, :A, :r1, :A_amt_, :B_amt_)}((false, false, false, false, false, false))

### create default events
nameless_events_active_ = NamedTuple{()}(())

### vector of non-steady-state
nameless_dynamic_nonss_ = NamedTuple{(:A_amt_, :B_amt_)}((true, true))

### initialization of ODE variables and Records
function nameless_init_func_!(__u0__, __p0__, __constants__)
  t = 0.0
  (k1,) = __constants__
  A_amt_ = 10.0 * 1.0
  B_amt_ = 0.0 * 1.0
  comp1 = 1.0
  __u0__[1] = A_amt_
  __u0__[2] = B_amt_
  __p0__[1] = comp1
  return nothing
end

### calculate RHS of ODE
function nameless_ode_func_(__du__, __u__, __p__, t)
  (comp1,) = __p__.x[1]
  (k1,) = __p__.x[2]
  (A_amt_, B_amt_) = __u__
  B = B_amt_ / comp1
  A = A_amt_ / comp1
  r1 = k1 * A * comp1
  __du__[1] = -r1
  __du__[2] = 2.0r1
  return nothing
end

### output function
function nameless_saving_generator_(__outputIds__::Vector{Symbol})
  __wrongIds__ = setdiff(__outputIds__, Symbol[:comp1, :B, :A, :r1, :A_amt_, :B_amt_])
  !isempty(__wrongIds__) && throw("The following outputs have not been found in the model: $(__wrongIds__)")

  __out_expr__ = Expr(:block)
  for (__i__, __obs__) in enumerate(__outputIds__)
    push!(__out_expr__.args, :(__out__[$__i__] = $__obs__))
  end

  return @eval function(__out__, __u__, t, __integrator__)
    (comp1,) = __integrator__.p.x[1]
    (k1,) = __integrator__.p.x[2]
    (A_amt_, B_amt_) = __u__
    B = B_amt_ / comp1
    A = A_amt_ / comp1
    r1 = k1 * A * comp1

    $(__out_expr__)
    return nothing
  end
end

### TIME EVENTS ###
nameless_time_events_ = NamedTuple{()}(())

### D EVENTS ###
nameless_discrete_events_ = NamedTuple{()}(())

### C EVENTS ###
nameless_continuous_events_ = NamedTuple{()}(())

### STOP EVENTS ###
nameless_stop_events_ = NamedTuple{()}(())

### MODELS ###

nameless_model_ = (
  nameless_init_func_!,
  nameless_ode_func_,
  nameless_time_events_,
  nameless_discrete_events_,
  nameless_continuous_events_,
  nameless_stop_events_,
  nameless_saving_generator_,
  nameless_constants_num_,
  nameless_statics_id_,
  nameless_events_active_,
  nameless_records_output_,
  nameless_dynamic_nonss_
)

### OUTPUT ###

return (
  (
    nameless = nameless_model_,
  ),
  (),
  "0.12.0"
)

end)()
