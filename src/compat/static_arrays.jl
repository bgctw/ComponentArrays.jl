function ComponentArray{A}(::UndefInitializer, ax::Axes) where {
        A <: StaticArray, Axes <: Tuple}
    return ComponentArray(similar(A), ax...)
end

_maybe_SArray(x::SubArray, ::Val{N}, ::FlatAxis) where {N} = SVector{N}(x)
function _maybe_SArray(x::Base.ReshapedArray, ::Val, ::ShapedAxis{Sz}) where {Sz}
    SArray{Tuple{Sz...}}(x)
end
function _maybe_SArray(x::SubArray, ::Val, ::ShapedAxis{Sz}) where {Sz}
    SArray{Tuple{Sz...}}(x)
end
_maybe_SArray(x, ::Val, ::Shaped1DAxis{Sz}) where {Sz} = SArray{Tuple{Sz...}}(x)
function _maybe_SArray(x, vals...) 
    x
end

@generated function static_getproperty(ca::ComponentVector, ::Val{s}) where {s}
    comp_ind = getaxes(ca)[1][s]
    #return :(ca[Val(s)])
    return :(_maybe_SArray(ca.$s, $(Val(length(comp_ind.idx))), $(comp_ind.ax)))
end

macro static_unpack(expr)
    @assert expr.head == :(=) "Unpack expression must have an equals sign for assignment"
    lhs, rhs = expr.args
    unpacked_var_names = if lhs isa Symbol
        [lhs]
    elseif lhs.head == :tuple
        if lhs.args[1] isa Expr
            lhs.args[1].args
        else
            lhs.args
        end
    else
        error("Malformed left side of assignment expression: $(lhs)")
    end
    parent_var_name = esc(rhs)
    out = Expr(:block)
    for name in unpacked_var_names
        esc_name = esc(name)
        push!(out.args, :($esc_name = static_getproperty($parent_var_name, $(Val(name)))))
    end
    return out
end

@generated function static_getproperty_col(ca::ComponentMatrix, ind::Val{s}) where {s}
    n_row = axis_length(getaxes(ca)[1])
    if n_row == 0
        @warn("@static_unpack_col: unknown number of rows, returning a view. " *
        "Specify axis of known length, e.g. Shaped1DAxis((4,)) or use @unpack_col_view.")
        return :(view(ca,:,Val(s))) # if size is unknown, return view into vector
    end
    comp_ind = getaxes(ca)[2][s]
    if comp_ind.ax isa NullAxis
        return :(_maybe_SArray(getdata(view(ca,:,Val(s))), $(Val(n_row)), FlatAxis()))
    else
        n_col = axis_length(comp_ind.ax)
        return :(_maybe_SArray(getdata(view(ca,:,Val(s))), $(Val(n_row * n_col)), ShapedAxis(($n_row, $n_col))))
    end
end

axis_length(ax::AbstractAxis) = lastindex(ax) - firstindex(ax) + 1
axis_length(::FlatAxis) = 0
axis_length(ax::UnitRange) = length(ax)
axis_length(ax::ShapedAxis) = length(ax)
axis_length(ax::Shaped1DAxis) = length(ax)



macro static_unpack_col(expr)
    @assert expr.head == :(=) "Unpack expression must have an equals sign for assignment"
    lhs, rhs = expr.args
    unpacked_var_names = if lhs isa Symbol
        [lhs]
    elseif lhs.head == :tuple
        if lhs.args[1] isa Expr
            lhs.args[1].args
        else
            lhs.args
        end
    else
        error("Malformed left side of assignment expression: $(lhs)")
    end
    parent_var_name = esc(rhs)
    out = Expr(:block)
    for name in unpacked_var_names
        esc_name = esc(name)
        push!(out.args, :($esc_name = static_getproperty_col($parent_var_name, $(Val(name)))))
    end
    return out
end

@generated function getproperty_col_view(ca::ComponentMatrix, ind::Val{s}) where {s}
    return :(view(ca,:,Val(s))) 
end


macro unpack_col_view(expr)
    @assert expr.head == :(=) "Unpack expression must have an equals sign for assignment"
    lhs, rhs = expr.args
    unpacked_var_names = if lhs isa Symbol
        [lhs]
    elseif lhs.head == :tuple
        if lhs.args[1] isa Expr
            lhs.args[1].args
        else
            lhs.args
        end
    else
        error("Malformed left side of assignment expression: $(lhs)")
    end
    parent_var_name = esc(rhs)
    out = Expr(:block)
    for name in unpacked_var_names
        esc_name = esc(name)
        push!(out.args, :($esc_name = getproperty_col_view($parent_var_name, $(Val(name)))))
    end
    return out
end


