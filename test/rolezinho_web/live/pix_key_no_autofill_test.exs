defmodule RolezinhoWeb.PixKeyNoAutofillTest do
  @moduledoc """
  Password managers repeatedly misidentify the Pix key input as a password
  field, because Pix keys often look like opaque strings and the field lives
  on the same screen as a real password. This is a UX regression waiting to
  happen (mangled Pix key + user confusion). These tests pin the ignore
  attributes so the two Pix key inputs stay opted out of every mainstream
  password manager's autofill.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp signed_in_conn(conn) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => "creator"
      })

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  # Every attribute we set on the Pix key input to keep autofill out.
  # `autocomplete="off"` is the HTML-standard hint; the three data-* attrs are
  # respected by the three mainstream password managers (1Password, LastPass,
  # Bitwarden); `data-form-type="other"` is a further 1Password nudge that
  # tells it "not a password form".
  @ignore_attrs [
    ~s(autocomplete="off"),
    ~s(data-1p-ignore="true"),
    ~s(data-lpignore="true"),
    ~s(data-bwignore="true"),
    ~s(data-form-type="other")
  ]

  describe "event create form" do
    test "the Pix key input carries every ignore attribute", %{conn: conn} do
      conn = signed_in_conn(conn)
      {:ok, _view, html} = live(conn, ~p"/criar")

      # Grab exactly the Pix key input line so we do not accidentally match
      # attributes on some other field.
      pix_input =
        Regex.run(~r|<input[^>]*name="event\[pix_key\]"[^>]*>|, html)
        |> List.first()

      assert pix_input, "expected a Pix key input on /criar"

      for attr <- @ignore_attrs do
        assert pix_input =~ attr,
               "expected the Pix key input to include #{attr}, got: #{pix_input}"
      end

      # And the field is not a password type — that would defeat the point.
      refute pix_input =~ ~s(type="password")
    end
  end

  describe "event edit form" do
    test "the Pix key input carries every ignore attribute", %{conn: conn} do
      {:ok, event} =
        Events.create(
          %{
            "title" => "T",
            "slug" => "pk-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          admin?: true
        )

      {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # The edit page now merges every text field into a single card, so
      # the Pix key input is named `details[pix_key]` instead of
      # `payment[pix_key]`. The autofill attributes must still be there.
      pix_input =
        Regex.run(~r|<input[^>]*name="details\[pix_key\]"[^>]*>|, html)
        |> List.first()

      assert pix_input, "expected a Pix key input on the edit page"

      for attr <- @ignore_attrs do
        assert pix_input =~ attr,
               "expected the Pix key input to include #{attr}, got: #{pix_input}"
      end

      refute pix_input =~ ~s(type="password")
    end
  end
end
