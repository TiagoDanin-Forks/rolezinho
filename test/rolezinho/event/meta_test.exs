defmodule Rolezinho.Event.MetaTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event.Meta

  describe "extract/1" do
    test "extracts canonical Local/Data/Horário lines and returns the rest untouched" do
      header = """
      Local: Rua Caripunas
      Data: 15/07/2026
      Horário: 19:00 (BRT)

      Valor: 15
      Pix: 91984933238
      """

      {meta, rest} = Meta.extract(header)

      assert meta.local == "Rua Caripunas"
      assert meta.date == ~D[2026-07-15]
      assert meta.time == ~T[19:00:00]

      # Free-form lines are preserved verbatim
      assert rest =~ "Valor: 15"
      assert rest =~ "Pix: 91984933238"
      # But the canonical meta lines are gone
      refute rest =~ "Local:"
      refute rest =~ "Data:"
      refute rest =~ "Horário:"
    end

    test "gracefully ignores malformed date/time lines" do
      {meta, rest} = Meta.extract("Data: not-a-date\nOutra coisa")
      assert meta.date == nil
      assert rest =~ "Data: not-a-date"
      assert rest =~ "Outra coisa"
    end

    test "returns empty meta and blank rest for nil/empty input" do
      assert {%Meta{local: nil, date: nil, time: nil}, ""} = Meta.extract(nil)
      assert {%Meta{}, ""} = Meta.extract("")
    end
  end

  describe "serialize/1 and build_header/2" do
    test "emits only the fields that are set" do
      assert Meta.serialize(%Meta{}) == ""

      assert Meta.serialize(%Meta{local: "Praia"}) == "Local: Praia"

      assert Meta.serialize(%Meta{date: ~D[2026-07-15]}) == "Data: 15/07/2026"

      assert Meta.serialize(%Meta{time: ~T[19:00:00]}) == "Horário: 19:00 (BRT)"

      full = %Meta{local: "Praia", date: ~D[2026-07-15], time: ~T[19:30:00]}

      assert Meta.serialize(full) ==
               "Local: Praia\nData: 15/07/2026\nHorário: 19:30 (BRT)"
    end

    test "build_header combines meta and description" do
      assert Meta.build_header(%Meta{local: "X"}, "detalhes") ==
               "Local: X\n\ndetalhes"

      # No meta -> just the description trimmed
      assert Meta.build_header(%Meta{}, "  detalhes  ") == "detalhes"

      # No description -> just the meta text
      assert Meta.build_header(%Meta{local: "X"}, nil) == "Local: X"
      assert Meta.build_header(%Meta{local: "X"}, "") == "Local: X"
    end

    test "round-trips through build_header + extract" do
      meta = %Meta{local: "Praia", date: ~D[2026-07-15], time: ~T[19:00:00]}
      header = Meta.build_header(meta, "Valor: 15\nPix: 91984933238")

      {parsed, rest} = Meta.extract(header)

      assert parsed == meta
      assert rest == "Valor: 15\nPix: 91984933238"
    end
  end

  describe "from_params/1" do
    test "reads HTML5 date/time inputs" do
      params = %{"local" => "Praia", "date" => "2026-07-15", "time" => "19:30"}

      assert %Meta{local: "Praia", date: ~D[2026-07-15], time: ~T[19:30:00]} =
               Meta.from_params(params)
    end

    test "leaves fields nil when inputs are empty" do
      assert %Meta{local: nil, date: nil, time: nil} =
               Meta.from_params(%{"local" => "", "date" => "", "time" => ""})
    end
  end

  describe "google_url/3" do
    test "returns nil when no date is set" do
      assert Meta.google_url(%Meta{}, "T", "http://x") == nil
      assert Meta.google_url(%Meta{local: "X"}, "T", "http://x") == nil
    end

    test "produces an all-day URL when only date is set" do
      url = Meta.google_url(%Meta{date: ~D[2026-07-15]}, "Vôlei", "http://roles/x")
      assert url =~ "dates=20260715%2F20260716"
      refute url =~ "ctz="
      assert url =~ "text=V%C3%B4lei"
    end

    test "produces a timed URL with BRT ctz and 2h default duration" do
      url =
        Meta.google_url(
          %Meta{local: "Praia", date: ~D[2026-07-15], time: ~T[19:00:00]},
          "Vôlei",
          "http://roles/x"
        )

      assert url =~ "dates=20260715T190000%2F20260715T210000"
      assert url =~ "ctz=America%2FSao_Paulo"
      assert url =~ "location=Praia"
    end
  end

  describe "ics/2" do
    test "returns nil when no date is set" do
      assert Meta.ics(%Meta{}, %{title: "T", slug: "s", url: "u", description: "d"}) == nil
    end

    test "all-day ics when only date" do
      ics =
        Meta.ics(%Meta{date: ~D[2026-07-15]}, %{
          title: "Vôlei",
          slug: "volei",
          url: "http://roles/volei",
          description: "Details"
        })

      assert ics =~ "DTSTART;VALUE=DATE:20260715"
      assert ics =~ "DTEND;VALUE=DATE:20260716"
      assert ics =~ "SUMMARY:Vôlei"
      # Uses CRLF as per RFC 5545
      assert ics =~ "\r\n"
    end

    test "converts BRT to UTC for timed events" do
      ics =
        Meta.ics(
          %Meta{date: ~D[2026-07-15], time: ~T[19:00:00], local: "Praia"},
          %{title: "T", slug: "s", url: "u", description: "d"}
        )

      # 19:00 BRT == 22:00 UTC; +2h duration -> 00:00 UTC next day
      assert ics =~ "DTSTART:20260715T220000Z"
      assert ics =~ "DTEND:20260716T000000Z"
      assert ics =~ "LOCATION:Praia"
    end
  end

  describe "format_when/1" do
    test "pretty-prints date + time in pt-BR" do
      # 15/07/2026 was a Wednesday
      assert Meta.format_when(%Meta{date: ~D[2026-07-15], time: ~T[19:00:00]}) =~
               "15 de julho de 2026 · 19:00 (BRT)"
    end

    test "handles date-only and time-only cases" do
      assert Meta.format_when(%Meta{date: ~D[2026-07-15]}) =~ "15 de julho"
      assert Meta.format_when(%Meta{time: ~T[19:00:00]}) == "19:00 (BRT)"
      assert Meta.format_when(%Meta{}) == ""
    end
  end
end
