defmodule Indexer do
  #import Chronos

  def test_corpus() do
    id = 0
    [%Document{id: id, title: "Studentbostäder på gång i Majorna",
      body: "SGS Studentbostäder planerar för ett stort bygge i Majorna. Om fyra år kan 280 nya lägenheter och en förskola stå klara.

Det är det största byggprojektet SGS Studentbostäder haft på närmare tio år, berättar fastighetschefen Magnus Bonander.

- För Göteborgs studenter är det bra att det blir ett så stort projekt. Det innebär ett rejält volymtillskott, men det löser förstås inte alla problem, säger han.",
    publish_date: {2015, 5, 4}, index_date: Chronos.now},
  %Document{id: id+1, title: "Uppskruvat tempo i Torslandafabriken",
    body: "Produktion dygnet runt och fler producerade bilar per timme. Volvo ökar tempot i Torslandafabriken för att klara efterfrågan på nya XC 90.

Enligt Mikael d’Aubigné, platschef för Torslandafabriken, har det inte varit några problem att få delar av den befintliga personalen att gå över till nattskift. På måndagen, efter första nattens arbete var han nöjd över resultatet.",
    publish_date: {2015, 5, 3}, index_date: Chronos.now},
  %Document{id: id+2, title: "Två döda efter vinterkräksjuka",
    body: "Två personer har avlidit efter en misstänkt matförgiftning på äldreboenden i Ljungby.

Prover visar att patienter drabbats av calicivirus - något som orsakar vinterkräksjuka. Men provsvaren från de hallon som misstänks ligga bakom utbrottet dröjer.

Smittskyddsenheten i länet har tagit flera patientprover som bekräftar misstankarna om att insjuknade personer drabbats av vinterkräksjuka.",
    publish_date: {2015, 5, 4}, index_date: Chronos.now},
  %Document{id: id+3, title: "Pojke föll från fjärde våningen",
    body: "En fyraårig pojke föll ut genom ett fönster i en bostad på fjärde våningen i Bergsjön. Han var ensam i lägenheten med sin tvååriga syster när han ramlade ut.

Larmet kom runt halv niotiden på måndagsmorgonen. En pojke i förskoleåldern hade fallit ut genom ett fönster i en bostad på fjärde våningen i Bergsjön, och landat på en gräsmatta. Polisen uppskattar fallhöjden till 20 meter.

- Det är högt alltså, jäkligt högt, säger Thomas Fuxborg, polisens presstalesman.",
    publish_date: {2015, 5, 5}, index_date: Chronos.now},
  %Document{id: 42, title: "Writing a search engine in Elixir",
    body: "Mkay so I decided to write cedrik as a fun exercise.. bye.",
    publish_date: {2015, 5, 18}, index_date: Chronos.now},
  %Document{id: 666, title: "cedrik the real froge",
    body: "Hello world! I am a test document :D",
    publish_date: {2015, 5, 18}, index_date: Chronos.now},
  ]
  end

  defimpl Store, for: Map do
    def store(map, index) do
      Indexer.index(map, index)
    end
  end

  def tokenize(text) do
    re = ~r/\W/iu # Match all non-words
    Regex.split(re, text) |> Enum.filter(fn(w) -> w != "" end)
  end

  def indexed?(doc, index) do
    Indexstore.get(index).document_ids
      |> Enum.member?(id(doc))
  end

  def index(doc, index) do
    case indexed?(doc, index) do
      true -> IO.puts("Document #{id(doc)} already present in #{index}")
      false -> index_doc(doc, index)
    end
  end

  def index_doc(doc, index) do
    id = id(doc)
    IO.puts("Indexing document with id #{id} into #{index}")
    terms = field_locations(doc) |> Enum.reduce(&merge_term_locations(&1, &2))
    idx = Indexstore.get(index)
      |> update_in([:terms], fn(ts) -> merge_term_locations(ts, terms) end)
      |> update_in([:document_ids], fn(ids) -> Set.put(ids, id) end)
    
    Documentstore.put(id, doc) # TODO move this
    {Indexstore.put(idx), idx}
  end

  def term_locations(docid, terms, field) do
    terms
      |> Enum.with_index
      |> Enum.map(fn({t, i}) ->
        Map.put(Map.new, t,
          Map.put(Map.new, docid,
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

  # TODO: Use an actual UUID instead of random
  def id(doc) when is_map(doc) do
    Map.get(doc, :id, Map.get(doc, "id", :random.uniform * 1000000))
  end

  def field_locations(doc) when is_map(doc) do
    id = id(doc)
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
  def should_index?({key, val}) do false end
end


