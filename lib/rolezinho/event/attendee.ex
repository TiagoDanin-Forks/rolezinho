defmodule Rolezinho.Event.Attendee do
  @moduledoc "A single spot in a list (may be empty)."

  defstruct name: "", paid: false

  @type t :: %__MODULE__{name: String.t(), paid: boolean()}
end
