struct CryptString
    value::String
end

parse(t::Type{CryptString}, a::AbstractString) = begin
    t(a)
end

function get_datatype(std::Type{AlgebraStreamFrames.StreamDataType{:Crypt}})
    CryptString
end