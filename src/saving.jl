# this is a modified version of SavingCallback from
# https://github.com/SciML/DiffEqCallbacks.jl/blob/master/src/saving.jl

#=
"""
    SavedValues{tType<:Real, output_valsType}
A struct used to save values of the time in `t::Vector{tType}` and
additional values in `output_vals::Vector{output_valsType}`.
"""
struct SavedValues{tType, output_valsType}
    t::Vector{tType}
    output_vals::Vector{output_valsType}
end


"""
    SavedValues(tType::DataType, output_valsType::DataType)
Return `SavedValues{tType, output_valsType}` with empty storage vectors.
"""
function SavedValues(::Type{tType}, ::Type{output_valsType}) where {tType,output_valsType}
    SavedValues{tType, output_valsType}(Vector{tType}(), Vector{output_valsType}())
end


function Base.show(io::IO, saved_values::SavedValues)
    tType = eltype(saved_values.t)
    output_valsType = eltype(saved_values.output_vals)
    print(io, "SavedValues{tType=", tType, ", output_valsType=", output_valsType, "}",
                "\nt:\n", saved_values.t, "\noutput_vals:\n", saved_values.output_vals)
end

@recipe function plot(saved_values::SavedValues)
    DiffEqArray(saved_values.t, saved_values.output_vals)
end
=#

mutable struct SavingEvent{SaveFunc, SavedValues, saveatType, saveatCacheType}
  save_func::SaveFunc
  saved_values::SavedValues
  saveat::saveatType
  saveat_cache::saveatCacheType
  save_everystep::Bool
  save_start::Bool
  save_end::Bool
  save_scope::Bool
  saveiter::Int
end

function (affect!::SavingEvent)(integrator,force_save = false; scope = :ode_)
  
  just_saved = false
  # see OrdinaryDiffEq.jl -> integrator_utils.jl, function output_valsues!
  while !isempty(affect!.saveat) && integrator.tdir * first(affect!.saveat) <= integrator.tdir * integrator.t # Perform saveat
      affect!.saveiter += 1
      curt = pop!(affect!.saveat) # current time

      if curt != integrator.t # If <t, interpolate
          if typeof(integrator) <: OrdinaryDiffEq.ODEIntegrator
              # Expand lazy dense for interpolation
              DiffEqBase.addsteps!(integrator)
          end
          if !DiffEqBase.isinplace(integrator.sol.prob)
              curu = integrator(curt)
          else
              curu = first(get_tmp_cache(integrator))
              integrator(curu,curt) # inplace since save_func allocates
          end
          copyat_or_push!(affect!.saved_values.t, affect!.saveiter, curt)
          affect!.save_scope && copyat_or_push!(affect!.saved_values.scope, affect!.saveiter, scope, Val{false})
          copyat_or_push!(affect!.saved_values.u, affect!.saveiter,
                          affect!.save_func(curu, curt, integrator),Val{false})
      else # ==t, just save
          just_saved = true
          copyat_or_push!(affect!.saved_values.t, affect!.saveiter, integrator.t)
          affect!.save_scope && copyat_or_push!(affect!.saved_values.scope, affect!.saveiter, scope, Val{false})
          copyat_or_push!(affect!.saved_values.u, affect!.saveiter, affect!.save_func(integrator.u, integrator.t, integrator),Val{false})
      end
  end
  if !just_saved &&
      affect!.save_everystep || force_save ||
      (affect!.save_end && integrator.t == integrator.sol.prob.tspan[end])

      affect!.saveiter += 1
      copyat_or_push!(affect!.saved_values.t, affect!.saveiter, integrator.t)
      affect!.save_scope && copyat_or_push!(affect!.saved_values.scope, affect!.saveiter, scope, Val{false})
      copyat_or_push!(affect!.saved_values.u, affect!.saveiter, affect!.save_func(integrator.u, integrator.t, integrator),Val{false})
  end
  u_modified!(integrator, false)
end

function saving_initialize(cb, u, t, integrator)
  if cb.affect!.saveiter != 0
      if integrator.tdir > 0
          cb.affect!.saveat = BinaryMinHeap(cb.affect!.saveat_cache)
      else
          cb.affect!.saveat = BinaryMaxHeap(cb.affect!.saveat_cache)
      end
      cb.affect!.saveiter = 0
  end
  clear_savings(cb.affect!.saved_values)
  cb.affect!.save_start && cb.affect!(integrator, scope=:start_)
end

function saving_wrapper(save_func, saved_values::SavedValues;
                      saveat=Vector{eltype(saved_values.t)}(),
                      save_everystep=isempty(saveat),
                      save_start = save_everystep || isempty(saveat) || saveat isa Number,
                      save_end = save_everystep || isempty(saveat) || saveat isa Number,
                      save_scope = true,
                      tdir=1)
  # saveat conversions, see OrdinaryDiffEq.jl -> integrators/type.jl
  saveat_vec = collect(saveat) 
  if tdir > 0
      saveat_internal = BinaryMinHeap(saveat_vec)
  else
      saveat_internal = BinaryMaxHeap(saveat_vec)
  end
  affect! = SavingEvent(save_func, saved_values, saveat_internal, saveat_vec, save_everystep, save_start, save_end, save_scope, 0)
  condtion = (u, t, integrator) -> true
  DiscreteCallback(condtion, affect!;
                   initialize = saving_initialize,
                   save_positions=(false,false))
end