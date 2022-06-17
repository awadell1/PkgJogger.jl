abstract type PkgJoggerException <: Exception end

"""
    InvalidIdentifier

The provided identifier is invalid or does not exist
"""
struct InvalidIdentifier <: PkgJoggerException
    id
    msg::String
end
InvalidIdentifier(id) = InvalidIdentifier(id, "")

function Base.showerror(io::IO, e::InvalidIdentifier)
    print(io, "The identifier \"$(e.id)\" is invalid or does not exist")
    !isempty(e.msg) && print(io, ". $(e.msg)")
end
