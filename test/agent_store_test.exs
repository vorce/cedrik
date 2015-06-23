defmodule AgentStoreTest do
  use ExUnit.Case, async: true

  setup_all do
    AgentStore.start_link()
    :ok
  end

  test "store and get doc" do
    doc = %{:id => "AgentStoreTest_id1", :foo => "bar"}
    
    AgentStore.put(Store.id(doc), doc)
    
    stored = AgentStore.get(Store.id(doc))
    assert stored.id == Store.id(doc)
    assert stored.foo == "bar"
  end
end