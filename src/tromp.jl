########################
# COUNTING AND UNRANKING
########################

"""
Calculate the number of De Bruijn terms of binary size n, with at most m free variables.

This corresponds to the series Sₘₙ from [this paper](https://arxiv.org/pdf/1511.05334v1.pdf).

Note that if you want to call this repeatedly, you should better create a table with
`tromptable(m, n)` with sufficiently large m, n and index into it. 
"""
function tromp(m::Integer, n::Integer, T::Type = Int)
    return tromptable(m, n, T)[n+1, m+1]
end

"""
Calculate the k-th De Bruijn term of binary size n, with at most m free variables.
    
Note that if you want to call this repeatedly, you should better create a table with
`tromptable(m, n)` for sufficiently large m, n and reuse it by calling
`unrank_with(m, n, k, table)`. 
"""
function unrank(m::Integer, n::Integer, k::Integer, T::Type = Int)
    @assert(m >= 0)
    @assert(n >= 0)
    @assert(k >= 0)

    unrank_with(m, n, k, tromptable(m, n, T))
end

"""
Generate the table of values of Sₙₘ, whose entries correspond to `tromp(n, m)`.

Note that the result uses "transposed" indices, and remember the offset introduced
by Julia's one-based indexing; so, `tromptable(x, y)[n+1, m+1]` corresponds to Sₘₙ.
"""
function tromptable(m::Integer, n::Integer, T::Type = Int)
    @assert(m >= 0)
    @assert(n >= 0)

    values = zeros(T, n+1, (n÷2)+2)
    
    for i = 2:n, j = 0:(n÷2)
        ti = values[1:(i-1), j+1]
        s = dot(ti, reverse(ti))
        values[i+1, j+1] = T(i-2 < j) + values[i-1, j+2] + s
    end

    # todo: cut/transpose this?
    return values
end

"""
Calculate the k-th De Bruijn term of binary size n, with at most m free variables,
using tabulated values for Sₙₘ.

This function should be used for repeated unrankings, so that the series Sₙₘ does
not have to be recomputed every time.
    
The argument `table` is expected to be in the format generated by `tromptable`, ie.,
with "transposed" indices (nm, not mn).
"""
function unrank_with{T <: Integer}(m::Integer, n::Integer, k::Integer, table::Array{T, 2})
    if m >= n-1 && k == table[n+1, m+1]
        return IVar(n-1)
    elseif k <= table[n-1, m+2]
        return IAbs(unrank_with(m+1, n-2, k, table))
    else
        function unrankApp(n, j, h)
            tmnj = table[n-j+1, m+1]
            tmjtmnj = table[j+1, m+1] * tmnj

            if h <= tmjtmnj
                dv, rm = divrem(h-1, tmnj)
                return IApp(unrank_with(m, j, dv+1, table), unrank_with(m, n-j, rm+1, table))
            else
                return unrankApp(n, j+1, h-tmjtmnj)
            end
        end

        return unrankApp(n-2, 0, k-table[n-1, m+2])
    end
end


# this is a patch needed to be able to use, eg, UInt
import Lazy.getindex
getindex(l::Lazy.List, i::Integer) = i <= 1 ? first(l) : tail(l)[i-1]


#################
# ITERATING TERMS
#################

"Iterate all De Bruijn terms of size n with at most m free variables."
terms(m::Integer, n::Integer, T::Type = Int) =
    TermsIterator{T}(m, n, tromptable(m, n, T))


immutable TermsIterator{T <: Integer}
    m :: T
    n :: T
    table :: Array{T, 2}
end

immutable TermsIteratorState{T <: Integer}
    k :: T
end

@inline increment{T <: Integer}(s::TermsIteratorState{T}) =
    TermsIteratorState{T}(s.k + 1)

Base.start{T <: Integer}(t::TermsIterator{T}) =
    TermsIteratorState{T}(1)
Base.next{T <: Integer}(t::TermsIterator{T}, state::TermsIteratorState{T}) =
    (unrank_with(t.m, t.n, state.k, t.table), increment(state))
Base.done{T <: Integer}(t::TermsIterator{T}, state::TermsIteratorState{T}) =
    state.k > t.table[t.n+1, t.m+1]
Base.length{T <: Integer}(t::TermsIterator{T}) =
    t.table[t.n+1, t.m+1]
Base.eltype{T <: Integer}(::Type{TermsIterator{T}}) = T
