defmodule AgentStoreTest do
  use ExUnit.Case, async: true

  setup_all do
    AgentStore.start_link()
    :ok
  end

  test "store and get doc" do
    doc = %{:id => "AgentStoreTest_id1", :foo => "bar"}
    id = Storable.id(doc)

    AgentStore.put(id, doc)

    stored = AgentStore.get(id)
    assert stored.id == id
    assert stored.foo == "bar"
  end
end
