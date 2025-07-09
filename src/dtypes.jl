abstract type AbstractCrypt end

struct CryptString <: AbstractCrypt
    value::String
end

parse(t::Type{<:AbstractCrypt}, a::AbstractString) = begin
    t(a)
end

function get_datatype(std::Type{AlgebraStreamFrames.StreamDataType{:Crypt}})
    CryptString
end

algebra_initializer(this_T::Type{<:AbstractCrypt}) = "null"

string(crypt::AbstractCrypt) = crypt.value::String

abstract type AbstractLong end