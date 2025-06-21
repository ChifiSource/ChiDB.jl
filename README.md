<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/laboratory/tools/chifiDB.png" width="120"></img>
</div>

###### a toolips-based data-base server
`ChiDB` is a unique data-base server designed around the `AlgebraFrames` concept and the `.ff` file format. Schema is laid using directories and filenames and data is live-read into memory. This is currently in a state of relative infancy, but is primarily being developed for my own use cases and to demonstrate the various server-building capabilities of `Toolips`.
#### setup
#### querying and headers
You will likely want an *API* of some sort to query a `ChiDB` servers. Every query, including your initial query, will be sent with a two-byte header. This header includes three fields: the `opcode` (4 bits), the `transaction id` (4 bits) (composing the first byte) and the second byte (8 bits) is dedicated to the *command character* -- a single-character reference that requests a query command.
- The `opcode` returns a success code dependent on the status of the last query. See [opcodes](#opcodes) for a full list of opcodes.
- The `transaction id` will be the ID of the transaction that is just issued. This needs to be sent **back** to the server on each query, and will need to be wrapped into each header we send to the server.

So, from the API's perspective both the opcode and transaction ID are sent back to the server, meaning we can just send back the first character we recieve as the header. The second char would then be our selected query command, and from there our arguments are provided directly and separated by `|!|`. For the initial connection the first character would be nothing, and for `S` we provide spaces as separators.
```julia
using Toolips

sock = Toolips.connect("127.0.0.1":2025)

write!(sock, "nS dbkey admin adminpwd\n")

resp = String(readavailable(sock))
# (opcode)
header = bitstring(resp[1:1])

if header[1:4] == "0001"
    println("query accepted!")
else
    throw("not verified, the query will not work")
end
# list tables:
write!(sock, resp[1:1] * "l")
```
###### commands
###### opcodes
