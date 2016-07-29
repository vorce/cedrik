defmodule Index do
  @doc "Index `thing` into the destination `index`"
  @callback index(thing :: any, index :: Atom.t) :: Atom.t

  @doc "Clear `index` and its contents"
  @callback clear(index :: Atom.t) :: Atom.t

  @doc "Delete a document with `docid` from `index`"
  @callback delete_doc(docid :: String.t, index :: Atom.t) :: Atom.t

  @doc "Returns all terms known for `index`"
  @callback terms(index :: Atom.t) :: Stream.t

  @doc """
  Returns a map of positions for each document where the term exist. Ex:
  %{"docId123" => [pos1, pos2], "docIdN" => [pos1]}
  """
  @callback term_positions(term :: String.t, index :: Atom.t) :: Map.t

  @doc "Returns all known document ids for `index`"
  @callback document_ids(index :: Atom.t) :: List.t

  @doc "Returns raw underlying CedrikIndex struct"
  @callback get(index :: Atom.t) :: Map.t

  def tokenize(text) do
    re = ~r/\W/iu # Match all non-words
    Regex.split(re, text)
      |> Enum.reject(fn(w) -> w == "" end)
  end

  def indexed?(id, index, type) do
    type.document_ids(index)
      |> Enum.member?(id)
  end

  @doc "Index a document (elixir map or structure) into index (pid or atom), type being either AgentIndex or RedisIndex."
  def index_doc(doc, index, type \\ AgentIndex) do
    pid = case IndexSupervisor.by_name(index) do
      {:error, _} ->
        {:ok, pid} = Supervisor.start_child(IndexSupervisor,
          Supervisor.Spec.worker(type, [[name: index]], id: index))
        pid
      {p, _m} -> p
    end

    case indexed?(Store.id(doc), pid, type) do
      true -> IO.puts("Document #{Store.id(doc)} already present in #{index} (type: #{type})")
      false -> index_doc_raw(doc, index, type)
    end
  end

  defp index_doc_raw(doc, index, type) do
    IO.puts("Indexing document with id #{Store.id(doc)} into #{inspect index} (type: #{type})")
    #terms = field_locations(id, doc)
    #  |> Enum.reduce(&merge_term_locations(&1, &2))

    type.index(doc, index)
    #idx = AgentIndex.get(index)
    #  |> update_in([:terms], fn(ts) -> merge_term_locations(ts, terms) end)
    #  |> update_in([:document_ids], fn(ids) -> Set.put(ids, id) end)

    # AgentStore.put(id, doc) # TODO move this?
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
    |> Map.to_list()
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
