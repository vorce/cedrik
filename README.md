[![Build Status](https://travis-ci.org/vorce/cedrik.svg?branch=master)](https://travis-ci.org/vorce/cedrik)
[![Inline docs](http://inch-ci.org/github/vorce/cedrik.svg?branch=HEAD&style=flat)](http://inch-ci.org/github/vorce/cedrik)

# Cedrik

A for-fun project of writing a small, naive search engine suitable for Small Data™ .

## (planned) features

- ☑ Indexing
- Queries:
    - ☑ MatchAll
    - ☑ Term (☐ boosting)
    - ☑ Boolean (And, Or, Not)
    - ☐ Near
    - ☑ Wildcard (Only single leading or single trailing is supported)
- ☐ Ranking
- ☐ Highlights
- ☐ Distributed indices (mnesia?, KVS?, riak?, redis?)
- ☐ Persistance (supported indirectly by using redis backed indices, but I would also like to add some simple compressed varitant for AgentIndex)
- ☐ Demo web UI (phoenix!)

## Usage

### Tests

Run unit tests:

    mix test --exclude external

Run all tests, including ones relying on external services. Such as the `RedisIndex` tests:

    mix test

**make sure you have the correct connection_string for redis in config/config.exs**.
You can use `docker-compose` to get a redis instance up and running quickly.

### Indexing

Each index in Cedrik is represented by a process with the `Index` `@behaviour`.
To index something into an index simply call `Index.index_doc(something, :index_name, type)` where
`something` would be an Elixir map or struct (I would recommend creating a struct, with an id field that implements the `Storable` protocol - have a look at `lib/document.ex` and `lib/agent_store.ex` for reference),
`type` must be one of the existing index implementations `AgentIndex` or `RedisIndex`. The last argument to `Index.index_doc` is optional and defaults to `AgentIndex`.

To get a list of existing indices use `Index.list/0` or `Index.list/1` - these will return a list of tuples on the format `{pid, name, module}`

#### AgentIndex

This is the naive in-memory index type, suitable for stuff that fits in memory and that does not need to be persisted.

#### RedisIndex

This is an index backed by redis. You must have a redis instance up and running for this to work. The main benefit of using a RedisIndex compared to AgentIndex is when you want to be able to persist data.

#### Tokenizing

For now a token is simply any string separated by spaces.

### Querying

Use `Search.search(query_struct, [:index1, :index2])`, see `test/e2e_test.exs` and `test/query_test.exs` for examples.

To get a `query_struct` that Cedrik understands, there is a simple (and incomplete) parser for strings: `Query.Parse.parse/1`.
It will tokenize strings and then construct Term and Wildcard query structs accordingly.
Terms and Wildcards will be wrapped in a Boolean, inside the must field.

#### MatchAll

This query will return all document ids in the specified indices.

#### Term

A TermQuery simply gives back the document ids (and the locations of the
term wihin that document) that contains the given term.
You can specify exactly what fields to look in, or all of them
(which is the default).

#### Boolean

With the BooleanQuery you can construct more advanced queries.
`must`, `optional` and `must_not`

#### Wildcard

This query can help broaden your hits. A Wildcard query with
value `"foo*"` matches both foo and foobar for example.
Note that only single wildcards are supported for now, either
leading (`*foo`) or trailing (`foo*`)

#### Near

### Results

At the moment results from `Search.search/2` will give you
a list of tuples that look like:
`{doc_id, #MapSet<[%Location{field: :field, position: x}]>}`
sorted by the stuff with most hits first.

#### Fields

#### Ranking
