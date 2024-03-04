piecewise(args...) = begin
  len = length(args)
  res = for i in 1:div(len, 2)
      if args[2*i]
          return args[2*i-1]
      end
  end
  if !isnothing(res)
      return res
  elseif mod(len, 2) === 1
      return args[len]
  else
      return NaN
  end
end