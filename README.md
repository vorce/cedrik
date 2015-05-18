# Cedrik

A for-fun project of writing a small search engine.

## (planned) features

- ☑ Indexing 
- Queries:
    - ☑ MatchAll
    - ☑ Term (☐ boosting)
    - ☐ And, Or, Not
    - ☐ Near 
    - ☐ Wildcard
- ☐ Distributed indices (mnesia?, KVS?, riak?)

## Usage

### Indexing stuff

Cedrik can take any Elixir map and index its contents for searching.
I would recommend creating a struct, with an id field. All string values
in the struct will then be tokenized and indexed
(unless the key is prefixed with underscore).
Make sure your struct `@derive [Access, Enumerable]`!

You can index a raw map, but make sure you have a :id or "id" key.

For examples, check out cedrik_test.exs, document.ex and indexer.ex

### Querying

#### MatchAll

#### Term

#### And

#### Or

#### Not

#### Near

#### Wildcard

### Result options

#### Fields

#### Sorting

