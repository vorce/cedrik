[![Build Status](https://travis-ci.org/vorce/cedrik.svg?branch=master)](https://travis-ci.org/vorce/cedrik)
[![Inline docs](http://inch-ci.org/github/vorce/cedrik.svg?branch=HEAD&style=flat)](http://inch-ci.org/github/vorce/cedrik)

# Cedrik

A for-fun project of writing a small search engine suitable for Small Data™ .

## (planned) features

- ☑ Indexing
- Queries:
    - ☑ MatchAll
    - ☑ Term (☐ boosting)
    - ☑ Boolean (And, Or, Not)
    - ☐ Near 
    - ☐ Wildcard (Only single leading or single trailing supported now)
- ☐ Ranking
- ☐ Highlights
- ☐ Distributed indices (mnesia?, KVS?, riak?, redis?)
- ☐ Demo web UI (phoenix!)

## Usage

### Tests

    mix test

Will run all unit and in-memory tests.

    mix test --include external:true

Will also run tests which rely on external services. Such as the `RedisIndex` tests,
**make sure you have the correct connection_string for redis in config/config.exs**.
You can use `docker-compose` to get a redis instance up and running quickly.

### Storing and Indexing

#### Storing

This is not necessarily related to searching. Storing something in Cedrik is just
a way to retrieve the original content in a straigh-forward manner.

#### Indexing

Indexing on the other hand is the term used in Cedrik for actually constructing an
inverted index suitable for free text queries.

##### Note that the following section is going to change very soon

Cedrik can take any Elixir map and index its contents for searching.
I would recommend creating a struct, with an id field, that
implements the Store protocol. Look at the example implementation
for Map and Document in `indexer.ex`.
Make sure your struct `@derive [Access, Enumerable]`!
`Indexer.index_doc/3` will skip indexing of any fields starting with underscore.

After your elixir data structure is indexed, where can you get it?
From the Store! Just do `AgentStore.get/1`

For examples, check out `test/indexing_test.exs`,
`lib/document.ex` and `indexer.ex`

#### Tokenizing

For now a token is simply any string separated by spaces.

### Querying

You can at any time access raw indices via `AgentIndex.get/1`, but
that is not very useful. Luckily Cedrik provides some shortcuts to
querying its indices.

#### MatchAll

This query will return all document ids in the specified indices.

TODO:
If you specify an empty list of indices, all documents in all indices
will be hits.

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
`{doc_id, #HashSet<[%Location{field: :field, position: x}]>}`
sorted by the stuff with most hits first.

#### Fields

#### Ranking

