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

parse(t::Type{Toolips.Components.File}, a::AbstractString) = begin
    Toolips.Components.File(a)
end

algebra_initializer(this_T::Type{Toolips.Components.File}) = File("/")

function get_datatype(std::Type{AlgebraStreamFrames.StreamDataType{:File}})
    File
end