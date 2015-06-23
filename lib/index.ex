defmodule Index do
  use Behaviour

  @doc "Index `thing` into the destination `index`"
  defcallback index(thing :: any, index :: String.t) :: Atom.t

  @doc "Uniquely identify the `thing`, must return a string"
  defcallback id(thing :: any) :: String.t

  @doc "Delete `index` and its contents"
  defcallback delete(index :: String.t) :: Atom.t

  @doc "Delete a document with `docid` from `index`"
  defcallback delete_doc(docid :: String.t, index :: String.t) :: Atom.t

  @doc "Returns all known indices"
  defcallback indices() :: List.t

  @doc "Returns all terms known for `index`"
  defcallback terms(index :: String.t) :: Stream.t

  @doc "Returns all known document ids for `index`"
  defcallback document_ids(index :: String.t) :: List.t
end
