defmodule Query.Parse do
  @moduledoc """
  Parses a string into a Query structure that Cedrik can understand.
  """

  @doc "Returns a Cedrik Query struct from a search string"
  # TODO describe the rules/syntax of the search string. Doctest?
  def parse(query_string) when is_binary(query_string) do
    String.split(query_string) |> parse()
  end

  def parse([query_string]) do
    single_word_query(query_string)
  end
  def parse(query_strings) when is_list(query_strings) do
     terms = query_strings
     |> Enum.map(&single_word_query/1)

     %Query.Boolean{must: terms}
  end

  defp single_word_query("*" <> _word = query_string) do
    %Query.Wildcard{value: query_string}
  end
  defp single_word_query(query_string) do
    case String.ends_with?(query_string, "*") do
       true -> %Query.Wildcard{value: query_string}
       false -> %Query.Term{value: query_string}
    end
  end
end