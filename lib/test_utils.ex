defmodule TestUtils do
  @moduledoc """
  Handy functions for test code
  """

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

  defmacro __using__(_) do
    quote location: :keep do
      def setup_corpus() do
        AgentIndex.start_link()
        AgentStore.start_link()
        TestUtils.test_corpus()
          |> Enum.each(fn(doc) ->
              #Store.store(doc, "test-index")
              AgentIndex.index(doc, "test-index")
            end)
        :ok
      end

      def ids(hits) do
        hits
          |> Enum.map(fn({id, _}) -> id end)
      end

      def locations(hits) do
        hits
          |> Enum.flat_map(fn{_, locs} -> Set.to_list(locs) end)
          |> Enum.map(fn(l) -> l.field end)
          |> Enum.uniq
      end
    end
  end
end
