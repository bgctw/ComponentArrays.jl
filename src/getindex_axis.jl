Base.getindex(cv::ComponentVector, ax::AbstractAxis) = _get_index_axis(cv,ax)
# avoid indexing by Vector - 
# Base.getindex(cv::ComponentVector, cv_template::ComponentVector) = _get_index_axis(
#     cv,first(getaxes(cv_template)))

function _get_index_axis(cv::CT, ax::AbstractAxis) where {T,CT<:ComponentVector{T}}
    first(getaxes(cv)) == ax && return(copy(cv)::CT) # no need to reassamble
    # extract subvectors and reassamble
    keys_ax = keys(ax)
    # k = keys_ax[1]
    fk = (k) -> begin
        !(k in propertynames(cv)) && error(
            "Expected key `$k` be present, but cv has only keys $(keys(cv))")
        cvs = getproperty(cv, k)
        axs = ax[k].ax
        #@show cvs, axs
        if cvs isa ComponentVector 
            (axs isa NullorFlatAxis) && length(ax[k].idx) != length(cvs) && error(
                    "Expect axis extracting component `$k` to extract n=$(length(cvs)) " * 
                    "elements, but was length($(length(ax[k].idx))).")
            cvk = _get_index_axis(cvs, axs)
            # create new ComponentVector as view to data of cvk
            axk = first(getaxes(cvk))
            axkv = ViewAxis(eachindex(cvk),axk)
            axv = Axis(NamedTuple{(k,)}((axkv,)))
            ComponentVector(getdata(cvk), (axv,))
        else
            cv[KeepIndex(k)] # need to rely on cv[KeepIndex] reuse base array type
        end
    end
    tmp = (fk(k) for k in keys_ax) # Generator: map changes base array type to Vector
    reduce(vcat, tmp)::ComponentVector{T}
end
_get_index_axis(x, ax::NullorFlatAxis) = error("unexpected dispatch")#x
# in order to extract entire component, do not need to specify subaxes, but length must match
# e.g. (a=1:2) to match entire (a=(a1=1, a2=2))
_get_index_axis(cv::ComponentVector, ax::NullorFlatAxis) = cv 

