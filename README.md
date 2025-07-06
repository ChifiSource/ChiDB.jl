<div align="center">
<img src="https://github.com/ChifiSource/image_dump/blob/main/laboratory/tools/chifiDB.png" width="120"></img>
</div>

###### a toolips-based data-base server
`ChiDB` is a unique data-base server designed around the `AlgebraFrames` concept and the `.ff` file format. Schema is laid using directories and filenames and data is live-read into memory. This is currently in a state of relative infancy, but is primarily being developed for my own use cases and to demonstrate the various server-building capabilities of `Toolips`.
- [get started](#get-started)
  - [adding chidb](#adding)
  - [documentation](#documentation)
- [chidb setup](#setup)
  - [schema](#schema)
    - [feature files](#feature-files)
    - [readable data-types](#readable-data-types)
    - [editing schema](#editing-schema)
- [querying](#querying)
  - [command list](#commands)
  - [query examples](#example-queries)
- [creating chidb clients](#creating-clients)
  - [chidb headers](#headers)
  - [existing clients](#existing-clients)
  - [opcode RFC](#opcodes)
 
## get started

#### adding

#### documentation

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
#### schema
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

##### feature files
Each `.ff` file's first line will be a readable data-type. For example, `col1.ff` from above could be
```ff
Integer
```
###### readable data-types

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
- `(table)/column` indicates the ability to provide the column if a table is selected.
<table>
  <tr>
    <th>character</th>
    <th>name</th>
    <th>description</th>
    <th>arguments</th>
  </tr>
  <tr>
    <td align="center">l</td>
    <td align="center">list</td>
    <td>lists the columns within a table, and their types, or lists all tables when provided with no argument</td>
    <td>(table)</td>
  </tr>
    <tr>
    <td align="center">s</td>
    <td align="center">select</td>
    <td align="center">Selects a table.</td>
    <td>table</td>
  </tr>
    <tr>
    <td align="center">t</td>
    <td align="center">create</td>
    <td align="center">creates a new table</td>
    <td>tablename</td>
  </tr>
    <tr>
      <th>
      <th>
    <th align="center">get-store commands</th>
      <th></th>
  </tr>
      <tr>
    <td align="center">g</td>
    <td align="center">get</td>
    <td align="center">gets values using vertical indexing</td>
    <td>(table)/column (range)</td>
  </tr>
        <tr>
    <td align="center">r</td>
    <td align="center">getrow</td>
    <td align="center">Gets a full row of data</td>
    <td>(table)/column rown</td>
  </tr>
          <tr>
    <td align="center">i</td>
    <td align="center">index</td>
    <td align="center">Gets the index where a certain value occurs in a given table.</td>
    <td>(table)/column value</td>
  </tr>
            <tr>
    <td align="center">a</td>
    <td align="center">store</td>
    <td align="center">Stores values, separated by `!;`, into a given table. Will return an argument error if the incorrect shape is provided.</td>
    <td>(table) value!;value2</td>
  </tr>
            <tr>
    <td align="center">v</td>
    <td align="center">set</td>
    <td align="center">Sets a singular value in a table.</td>
    <td>(table)/column row value</td>
  </tr>
              <tr>
    <td align="center">w</td>
    <td align="center">setrow</td>
    <td align="center">Sets the values of an entire row on a table</td>
    <td>(table) row value1!;value2</td>
  </tr>
            <tr>
    <th align="center"></th>
    <th align="center"></th>
    <th align="center">column management</th>
    <th></th>
  </tr>
              <tr>
    <td align="center">j</td>
    <td align="center">join</td>
    <td align="center">Adds a new column to a frame, creates a reference column when used with a column path from another table.</td>
    <td>(table) (reftable)/colname (Type)</td>
  </tr>
                <tr>
    <td align="center">k</td>
    <td align="center">type</td>
    <td align="center">Attempts to cast a given type to a provided column.</td>
    <td>(table)/colname Type</td>
  </tr>
                <tr>
    <td align="center">e</td>
    <td align="center">rename</td>
    <td align="center">Renames a given column or table</td>
    <td>(table) table_or_colname</td>
  </tr>
              <tr>
    <th align="center"></th>
    <th align="center"></th>
    <th align="center">deleters</th>
    <th></th>
                <tr>
    <td align="center">d</td>
    <td align="center">deleteat</td>
    <td align="center">Deletes a row from a given table.</td>
    <td>(table) row</td>
  </tr>
                  <tr>
    <td align="center">z</td>
    <td align="center">delete</td>
    <td align="center">Deletes a table</td>
    <td>table</td>
  </tr>
                <tr>
    <th align="center"></th>
    <th align="center"></th>
    <th align="center">built-in operations</th>
    <th></th>
                <tr>
                                <tr>
    <th align="center"></th>
    <th align="center"></th>
    <th align="center">server</th>
    <th></th>
                <tr>
</table>

###### opcodes

<div align="center">
<table>
  <tr>
  <th>code</th>
  <th>status</th>
  <th>name</th></th>
  <th>has output</th>
</tr>
  <tr>
    <td align="center">0001</td>
    <td align="center"><b>OK</b></td>
    <td align="center">query accept</td>
    <td align="center">false</td>
  </tr>
    <tr>
    <td align="center">0011</td>
    <td align="center"><b>OK</b></td>
    <td align="center">user created</td>
    <td align="center">false</td>
  </tr>
  <tr>
    <td align="center">0101</td>
    <td align="center"><b>OK</b></td>
    <td align="center">password set</td>
    <td align="center">false</td>
  </tr>
    <tr>
    <td align="center">1000</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">bad packet</td>
    <td align="center">false</td>
  </tr>
      <tr>
    <td align="center">1100</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">login denied (connection closed)</td>
    <td align="center">false</td>
  </tr>
        <tr>
    <td align="center">1001</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">bad dbkey (connection closed)</td>
    <td align="center">false</td>
  </tr>
    <tr>
    <td align="center">1110</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">command error</td>
    <td align="center">true</td>
  </tr>
      <tr>
    <td align="center">1010</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">argument error</td>
    <td align="center">true</td>
  </tr>
        <tr>
    <td align="center">1111</td>
    <td align="center"><b>ERROR</b></td>
    <td align="center">bad transaction (connection closed)</td>
    <td align="center">false</td>
  </tr>
</table>
</div>
