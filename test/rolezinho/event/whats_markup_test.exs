defmodule Rolezinho.Event.WhatsMarkupTest do
  @moduledoc """
  The organizer types the way they type in the group; this is what turns that
  into markdown. The interesting cases are all about *not* converting: an
  asterisk in arithmetic and an underscore in a file name are far more common in
  a hangout description than deliberate emphasis.
  """
  use ExUnit.Case, async: true

  doctest Rolezinho.Event.WhatsMarkup

  alias Rolezinho.Event.WhatsMarkup

  describe "the four spans" do
    test "bold doubles the asterisk" do
      assert WhatsMarkup.to_markdown("Leva *água*") == "Leva **água**"
    end

    test "italic becomes a single asterisk" do
      assert WhatsMarkup.to_markdown("Quadra _3_") == "Quadra *3*"
    end

    test "strikethrough doubles the tilde" do
      assert WhatsMarkup.to_markdown("~cancelado~") == "~~cancelado~~"
    end

    test "code spans pass through untouched" do
      assert WhatsMarkup.to_markdown("use `git status`") == "use `git status`"
    end

    test "all of them in one line" do
      assert WhatsMarkup.to_markdown("*a* e _b_ e ~c~") == "**a** e *b* e ~~c~~"
    end
  end

  describe "what must not be converted" do
    test "an asterisk used as multiplication" do
      assert WhatsMarkup.to_markdown("5 * 3 = 15") == "5 * 3 = 15"
    end

    test "underscores inside a word" do
      assert WhatsMarkup.to_markdown("arquivo_nome_teste") == "arquivo_nome_teste"
    end

    test "markup characters inside a code span" do
      # Backticks mean "leave this alone" in both dialects.
      assert WhatsMarkup.to_markdown("`*nao*`") == "`*nao*`"
    end

    test "a delimiter with a space against it" do
      # WhatsApp requires the delimiters to touch non-space, and so does this.
      assert WhatsMarkup.to_markdown("* nao *") == "* nao *"
    end

    test "an unclosed delimiter" do
      assert WhatsMarkup.to_markdown("*sozinho") == "*sozinho"
    end

    test "a delimiter spanning a line break" do
      assert WhatsMarkup.to_markdown("*a\nb*") == "*a\nb*"
    end
  end

  describe "edge cases" do
    test "empty and nil" do
      assert WhatsMarkup.to_markdown("") == ""
      assert WhatsMarkup.to_markdown(nil) == ""
    end

    test "a literal placeholder in the text survives" do
      # The code-span placeholder is a control character precisely so that text
      # like this cannot collide with it.
      assert WhatsMarkup.to_markdown("code0 e code1") == "code0 e code1"
    end

    test "two code spans keep their own contents" do
      assert WhatsMarkup.to_markdown("`um` e `dois`") == "`um` e `dois`"
    end

    test "plain text is returned unchanged" do
      assert WhatsMarkup.to_markdown("Leva água. Quadra 3.") == "Leva água. Quadra 3."
    end
  end
end
