defmodule Rolezinho.Event.CanonicalNameTest do
  @moduledoc """
  `Attendee.canonical_name/1` — the dedup key for the join-form
  autocomplete. Same person, different typings, one entry.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Event.Attendee

  test "trims leading and trailing whitespace" do
    assert Attendee.canonical_name("  Pedro  ") == "Pedro"
  end

  test "title-cases each word" do
    assert Attendee.canonical_name("pedro costa") == "Pedro Costa"
    assert Attendee.canonical_name("PEDRO COSTA") == "Pedro Costa"
    assert Attendee.canonical_name("Pedro COSTA") == "Pedro Costa"
  end

  test "collapses interior whitespace to a single space" do
    assert Attendee.canonical_name("Pedro    Costa") == "Pedro Costa"
    assert Attendee.canonical_name("Pedro\tCosta") == "Pedro Costa"
  end

  test "the mixed-case example from the spec dedups" do
    assert Attendee.canonical_name("Pedro costa") ==
             Attendee.canonical_name("pedro Costa")
  end

  test "empty/whitespace/nil collapse to \"\"" do
    assert Attendee.canonical_name("") == ""
    assert Attendee.canonical_name("   ") == ""
    assert Attendee.canonical_name(nil) == ""
  end

  test "single-name inputs still title-case" do
    assert Attendee.canonical_name("MARCIA") == "Marcia"
  end

  test "preserves Unicode letters" do
    assert Attendee.canonical_name("márcia da silva") == "Márcia Da Silva"
  end
end
