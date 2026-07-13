defmodule Rolezinho.EventTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  @sample """
  # VÔLEI VER-O-BEACH

  End: Rua Caripunas
  QUARTA-FEIRA (15/07)
  Horário: 19 as 21
  Valor: 15
  Pix: 91984933238

  1- Márcia ✅️
  2- Robertinha
  3- Henrique ✅
  4- Yngrid ✅
  5- Matheus ✅️
  6- Leticia ✅️
  7- João ✅
  8- Kelly ✅
  9- Karina✅
  10 -
  11- Tiago Danin ✅
  12- Gaby ✅
  13- Eduardo (conv. Karina)✅
  14- Gisele (conv. Yngrid)✅
  15-  anna clara ✅️
  16- viny ✅️
  17- Miguel
  18- Diego

  Lista de reserva
  1- Rivanete (conv João)
  2-
  3-

  *PAGAMENTO APENAS NO PIX*
  """

  test "parses the sample markdown" do
    event = Event.parse(@sample, slug: "volei")

    assert event.title == "VÔLEI VER-O-BEACH"
    assert String.contains?(event.header, "End: Rua Caripunas")
    assert String.contains?(event.header, "Pix: 91984933238")

    assert event.main_capacity == 18
    assert length(event.main_list) == 18

    # Márcia is paid
    assert %Attendee{name: "Márcia", paid: true} = Enum.at(event.main_list, 0)
    # Robertinha not paid
    assert %Attendee{name: "Robertinha", paid: false} = Enum.at(event.main_list, 1)
    # slot 10 empty
    assert %Attendee{name: "", paid: false} = Enum.at(event.main_list, 9)
    # Diego last, not paid
    assert %Attendee{name: "Diego", paid: false} = Enum.at(event.main_list, 17)

    assert event.wait_enabled
    assert event.wait_intro == "Lista de reserva"
    # Only real attendees survive parsing; empty wait slots are dropped since the
    # wait list is conceptually infinite.
    assert length(event.wait_list) == 1
    assert %Attendee{name: "Rivanete (conv João)"} = Enum.at(event.wait_list, 0)

    assert String.contains?(event.footer, "PAGAMENTO APENAS NO PIX")
  end

  test "normalize_main compacts empty slots to the end" do
    event =
      Event.parse(@sample, slug: "x")
      |> Event.normalize_main()

    # after normalization slot 10 (empty) should be pushed to end
    # first 17 slots are filled, last one empty
    filled_count =
      Enum.count(event.main_list, fn %Attendee{name: n} -> n != "" end)

    assert filled_count == 17
    assert %Attendee{name: ""} = Enum.at(event.main_list, 17)
    assert %Attendee{name: "Diego"} = Enum.at(event.main_list, 16)
  end

  test "add_to_main fills first empty slot" do
    event =
      Event.parse(@sample, slug: "x")
      |> Event.normalize_main()

    {:ok, event} = Event.add_to_main(event, "Novato")
    # position 18 (index 17) should now be Novato
    assert %Attendee{name: "Novato"} = Enum.at(event.main_list, 17)
  end

  test "add_to_main returns error when full" do
    event = %Event{
      title: "T",
      main_capacity: 2,
      main_list: [%Attendee{name: "A"}, %Attendee{name: "B"}]
    }

    assert {:error, :main_full} = Event.add_to_main(event, "C")
  end

  test "remove_main shifts everyone up" do
    event = %Event{
      title: "T",
      main_capacity: 4,
      main_list: [
        %Attendee{name: "A"},
        %Attendee{name: "B"},
        %Attendee{name: "C"},
        %Attendee{name: "D"}
      ]
    }

    event = Event.remove_main(event, 2)
    assert Enum.map(event.main_list, & &1.name) == ["A", "C", "D", ""]
  end

  test "promote moves a wait list entry to main" do
    event = %Event{
      title: "T",
      main_capacity: 3,
      main_list: [
        %Attendee{name: "A"},
        %Attendee{name: ""},
        %Attendee{name: "C"}
      ],
      wait_enabled: true,
      wait_list: [%Attendee{name: "W1"}, %Attendee{name: "W2"}]
    }

    {:ok, event} = Event.promote(event, 1)
    assert Enum.map(event.main_list, & &1.name) == ["A", "W1", "C"]
    assert Enum.map(event.wait_list, & &1.name) == ["W2"]
  end

  test "toggle_paid_main flips the flag" do
    event = %Event{
      title: "T",
      main_capacity: 2,
      main_list: [%Attendee{name: "A", paid: false}, %Attendee{name: "B", paid: true}]
    }

    event = Event.toggle_paid_main(event, 1)
    assert Enum.at(event.main_list, 0).paid == true
    event = Event.toggle_paid_main(event, 2)
    assert Enum.at(event.main_list, 1).paid == false
  end

  test "resize_main can grow but never shrinks below filled" do
    event = %Event{
      title: "T",
      main_capacity: 3,
      main_list: [%Attendee{name: "A"}, %Attendee{name: "B"}, %Attendee{name: ""}]
    }

    grown = Event.resize_main(event, 6)
    assert grown.main_capacity == 6
    assert length(grown.main_list) == 6

    shrunk = Event.resize_main(event, 1)
    assert shrunk.main_capacity == 2
    assert Enum.map(shrunk.main_list, & &1.name) == ["A", "B"]
  end

  describe "to_text/2" do
    test "prepends the URL and collapses empty slots into a summary" do
      event = %Event{
        title: "T",
        header: "Praia",
        main_capacity: 5,
        main_list: [
          %Attendee{name: "A"},
          %Attendee{name: "B"},
          %Attendee{},
          %Attendee{},
          %Attendee{}
        ],
        wait_enabled: true,
        wait_intro: "Lista de reserva",
        wait_list: [%Attendee{name: "W1"}]
      }

      text = Event.to_text(event, "https://roles.lubien.me/r/x")

      # URL at top, followed by a blank line and then the title
      assert String.starts_with?(text, "https://roles.lubien.me/r/x\n\nT")

      # Empty slots are collapsed into a single summary line, not shown one-by-one
      assert text =~ "3 vagas: https://roles.lubien.me/r/x"
      refute text =~ "3-"
      refute text =~ "4-"
      refute text =~ "5-"

      # Wait list always has a call-to-action
      assert text =~ "Entrar na espera: https://roles.lubien.me/r/x"
    end

    test "pluralizes vagas correctly and omits the line when full" do
      event = %Event{
        title: "T",
        main_capacity: 3,
        main_list: [%Attendee{name: "A"}, %Attendee{name: "B"}, %Attendee{}],
        wait_enabled: false
      }

      assert Event.to_text(event, "http://u/x") =~ "1 vaga: http://u/x"

      full = %{
        event
        | main_list: [%Attendee{name: "A"}, %Attendee{name: "B"}, %Attendee{name: "C"}]
      }

      refute Event.to_text(full, "http://u/x") =~ ~r/vagas?:/
    end

    test "works without a URL for backwards compatibility" do
      event = %Event{
        title: "T",
        main_capacity: 2,
        main_list: [%Attendee{name: "A"}, %Attendee{}],
        wait_enabled: false
      }

      text = Event.to_text(event)
      assert text =~ "1 vaga"
      refute text =~ "http"
    end
  end

  test "round-trips through render/parse" do
    event = Event.parse(@sample, slug: "x") |> Event.normalize_main()
    rendered = Event.render(event)
    reparsed = Event.parse(rendered, slug: "x")

    assert reparsed.title == event.title
    assert reparsed.main_capacity == event.main_capacity
    assert reparsed.wait_enabled
    assert Enum.map(reparsed.main_list, & &1.name) == Enum.map(event.main_list, & &1.name)
    assert Enum.map(reparsed.main_list, & &1.paid) == Enum.map(event.main_list, & &1.paid)
    assert Enum.map(reparsed.wait_list, & &1.name) == Enum.map(event.wait_list, & &1.name)
  end
end
