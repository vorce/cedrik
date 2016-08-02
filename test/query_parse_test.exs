defmodule Query.ParseTest do
  use ExUnit.Case, async: true

  test "single word" do
     input = "cedrik"

     result = Query.Parse.parse(input)

     assert result == %Query.Term{value: input}
  end

  test "multiple words" do
    input = "cedrik rules"

    result = Query.Parse.parse(input)

    assert result == %Query.Boolean{
      must: [%Query.Term{value: "cedrik"}, %Query.Term{value: "rules"}]}
  end

  test "beginning wildcard" do
    input = "*cedrik rules"

    result = Query.Parse.parse(input)

    assert result == %Query.Boolean{
      must: [%Query.Wildcard{value: "*cedrik"}, %Query.Term{value: "rules"}]}
  end

  test "ending wildcard" do
    input = "cedrik rules*"

    result = Query.Parse.parse(input)

    assert result == %Query.Boolean{
      must: [%Query.Term{value: "cedrik"}, %Query.Wildcard{value: "rules*"}]}
  end
end
