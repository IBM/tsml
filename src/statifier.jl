module Statifiers

using StatsBase: std, skewness, kurtosis, variation, sem, mad,  entropy, summarystats, autocor, pacf, rle
using Dates
using DataFrames
using Random

export fit!,transform!
export Statifier

export fullstat,statifierrun

using TSML.TSMLTypes
import TSML.TSMLTypes.fit! # to overload
import TSML.TSMLTypes.transform! # to overload
using TSML.Utils


# Transforms instances with nominal features into one-hot form
# and coerces the instance matrix to be of element type Float64.
mutable struct Statifier <: Transformer
  model
  args

  function Statifier(args=Dict())
    default_args = Dict(
      :processmissing => true
    )
    new(nothing, mergedict(default_args, args))
  end
end

function fit!(st::Statifier, features::T=[], labels::Vector=[]) where {T<:Union{Vector,Matrix,DataFrame}}
  typeof(features) <: Vector || error("Statifier.fit!: data should be a vector")
  st.model = st.args
end

function transform!(st::Statifier, features::T=[]) where {T<:Union{Vector,Matrix,DataFrame}}
  features != [] || return DataFrame()
  typeof(features) <: Vector || error("Statifier.fit!: data should be a vector")
  fstat = fullstat(features)
  if st.args[:processmissing] == true
    # full namedtuple: stat1,stat2,bstat
    hcat(fstat...)
  else
    hcat(fstat.stat1,fstat.stat2)
  end
end

function fullstat(dat::Vector)
  data = skipmissing(dat) |> collect
  lsm = summarystats(data)
  lks = kurtosis(data)
  lsk = skewness(data)
  lvar = variation(data)
  lsem = sem(data)
  lentropy = entropy(data)
  # assume 24-hour period
  _autolags = 1:minimum([24,length(data)-1])
  _pacflags = 1:minimum([24,div(length(data),2)-1])
  lautocor = autocor(data,_autolags) .|> abs2 |> sum |> sqrt
  lpacf = pacf(data,_pacflags) .|> abs2 |> sum |> sqrt
  lbrle = rlestatmissingblocks(dat)
  df1=DataFrame(median=lsm.median,mean=lsm.mean,q25=lsm.q25,q75=lsm.q75)
  df2=DataFrame(kurtosis=lks,skewness=lsk,variation=lvar,entropy=lentropy,
            autocor=lautocor,pacf=lpacf)
  df3=DataFrame(bmedian=lbrle.bmedian,bmean=lbrle.bmean,bq25=lbrle.bq25,bq75=lbrle.bq75)
  return (stat1=df1,stat2=df2,bstat=df3)
end

function rlestatmissingblocks(dat::Vector{T}) where {T<:Union{AbstractFloat,Integer,Missing}}
  data = deepcopy(dat)
  # replace missing with dummy value for rle processing
  indxmissing=findall(x->ismissing(x),data)
  dummy = -99999
  if eltype(data) <: Union{AbstractFloat,Missing}
    data[indxmissing] .= dummy
  elseif eltype(data) <: Union{Integer,Missing}
    data[indxmissing] .= dummy  
  else
    error("not a valid type")
  end
  _rle = rle(data)
  indx=findall(x->x == dummy,_rle[1])
  blocks = _rle[2][indx]
  _sm = summarystats(blocks)
  #maxblock = maximum(blocks)
  #meanblock = mean(blocks)
  #medianblock = mad(blocks,normalize=true)
  #return (maxblock = maxblock, meanblock=meanblock,medianblock=medianblock)
  return (bq25=_sm.q25,bmean=_sm.mean,bmedian=_sm.median,bq75=_sm.q75)
end

function statifierrun()
  Random.seed!(123)
  dat=[missing;rand(1:10,3);missing;missing;missing;rand(1:5,3)]
  statfier = Statifier(Dict(:processmissing=>false))
  fit!(statfier,dat)
  res=transform!(statfier,dat)
  @show res
  statfier = Statifier(Dict(:processmissing=>true))
  fit!(statfier,dat)
  res=transform!(statfier,dat)
  @show res
  return nothing
end


end
