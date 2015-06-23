defmodule Indexer do

  defimpl Store, for: [Map, Document] do
    def store(doc, index) do
      #Indexer.index(id(map), map, index)
      AgentStore.put(id(doc), doc)
    end

    # TODO: Use some actual UUID here instead of random
    def id(doc) do
      Map.get(doc, :id,
        Map.get(doc, "id", :random.uniform * 1000000))
      |> to_string
    end

    def delete(doc, index) do
      AgentStore.delete([id(doc)])
      #AgentIndex.delete_doc(map, index)
    end
  end

  def tokenize(text) do
    re = ~r/\W/iu # Match all non-words
    Regex.split(re, text)
      |> Enum.reject(fn(w) -> w == "" end)
  end

  def indexed?(id, index, type) do
    type.document_ids(index)
      |> Enum.member?(id)
    #AgentIndex.get(index).document_ids
    #  |> Enum.member?(id)
  end

  def index(id, doc, index, type) do
    case indexed?(id, index, type) do
      true -> IO.puts("Document #{id} already present in #{index} (type: #{type})")
      false -> index_doc(id, doc, index, type)
    end
  end

  def index_doc(id, doc, index, type) do
    IO.puts("Indexing document with id #{id} into #{index} (type: #{type})")
    #terms = field_locations(id, doc)
    #  |> Enum.reduce(&merge_term_locations(&1, &2))

    type.index(doc, index, type)
    #idx = AgentIndex.get(index)
    #  |> update_in([:terms], fn(ts) -> merge_term_locations(ts, terms) end)
    #  |> update_in([:document_ids], fn(ids) -> Set.put(ids, id) end)
    
    #AgentStore.put(id, doc) # TODO move this?
    #{AgentIndex.put(idx), idx}
  end

  def term_locations(id, terms, field) do
    terms
      |> Enum.with_index
      |> Enum.map(fn({t, i}) ->
        Map.put(Map.new, t,
          Map.put(Map.new, id,
            Set.put(HashSet.new, %Location{field: field, position: i})))
        end)
  end

  # merges maps on format: %{"w" => %{n => [...], n2 => ...}, "w2" => ...}
  def merge_term_locations(t1, t2) do
    Map.merge(t1, t2,
      fn(_k, d1, d2) -> Map.merge(d1, d2,
        fn(_k2, l1, l2) ->
          Enum.concat(l1, l2) |> Enum.into(HashSet.new) end)
      end)
  end

  def field_locations(id, doc) when is_map(doc) do
    doc
      |> Enum.filter(&should_index?(&1))
      |> Enum.flat_map(fn({k, v}) ->
        term_locations(id, tokenize(v), k) end)
  end

  def should_index?({key, val}) when is_atom(key) and is_binary(val) do
    k = Atom.to_string(key)
    case String.starts_with?(k, "_") or key == :id do
      true -> false
      false -> true
    end
  end
  def should_index?({key, val}) when is_binary(key) and is_binary(val) do
    case String.starts_with?(key, "_") or key == "id" do
      true -> false
      false -> true
    end
  end
  def should_index?({_key, _val}) do false end
end


