<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/laboratory/tools/chifiDB.png" width="120"></img>
</div>

###### a toolips-based data-base server
`ChiDB` is a unique data-base server designed around the `AlgebraFrames` concept and the `.ff` file format. Schema is laid using directories and filenames and data is live-read into memory. This is currently in a state of relative infancy, but is primarily being developed for my own use cases and to demonstrate the various server-building capabilities of `Toolips`.
## setup
In order to use `ChiDB`, we first need [julia](https://julialang.org). With Julia installed, the package may be added with `Pkg`:
```julia
using Pkg; Pkg.add(url = "https://github.com/ChifiSource/ChiDB.jl")
using ChiDB
```
To setup a `ChiDB` server directory, run `ChiDB.start` and provide an **empty** directory as `path`. This will create a new folder called `db`, which will contain the data-bases core information.
```julia
start(path::String, ip::IP4 = "127.0.0.1":8005)
```
Our `admin` login will also be printed here; by querying with this new `admin` login we may create new users.
#### loading schema
Once we have a data-base server and its directory, we are going to need to create schema. There are two ways to create your schema:
- *querying*
- or by simply creating a filesystem.

`ChiDB`'s internal data is primarily stored in the `.ff` (*feature file*) format. There are no sub-tables, only reference columns. Both references and `.ff` feature files are represented by files, and the tables they reside in are represented by directories. In order to create schema, we would simply add new folders with new `.ff` files for each column to our new data-base directory. Consider the following sample directory structure:
- project directory
  - /db
  - /table1
    - /col1.ff
    - /col2.ff
    - /table2_col1.ref
  - /table2
    - /col1.ff

Each `.ff` file's first line will be a readable data-type. For example, `col1.ff` from above could be
```ff
Integer
```
## readable data-types
## usage

#### querying

#### headers
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
- `()` indicates an optional argument.
<table>
  <tr>
    <th>header character</th>
    <th>name</th>
    <th>description</th>
    <th>standard name</th>
    <th>arguments</th>
  </tr>
  <tr>
    <td align="center">l</td>
    <td>list</td>
    <td>lists the columns within a table, and their types, or lists all tables when provided with no argument</td>
    <td>list</td>
    <td>(table)</td>
  </tr>
    <tr>
    <td align="center">s</td>
    <td align="center">select</td>
    <td>Selects a table.</td>
    <td align="center">select</td>
    <td>table</td>
  </tr>
</table>

###### opcodes
