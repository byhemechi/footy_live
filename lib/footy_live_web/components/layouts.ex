defmodule FootyLiveWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use FootyLiveWeb, :html

  embed_templates "layouts/*"

  defp sentry_scripts(assigns) do
    assigns =
      assign(assigns,
        sentry_dsn: Sentry.get_dsn()
      )

    ~H"""
    <%= if is_binary(@sentry_dsn) do %>
      <meta name="sentry-dsn" content={@sentry_dsn} />
      <link
        rel="preconnect"
        href={URI.parse(@sentry_dsn) |> Map.put(:path, nil) |> URI.to_string()}
        crossorigin="use-credentials"
      />
      <script type="module" src={~p"/assets/sentry.js"} defer />
    <% end %>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="absolute">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card tabs  tabs-box p-1 relative flex flex-row">
      <div class="theme-selector-handle absolute size-8 tab tab-active ml-1 left-0 [[data-theme=light]_&]:left-8 [[data-theme=dark]_&]:left-16 transition-[left]" />
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer text-base-content/75 hover:text-base-content"
        aria-label="Use system theme"
        title="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer text-base-content/75 hover:text-base-content"
        aria-label="Use light theme"
        title="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer text-base-content/75 hover:text-base-content"
        aria-label="Use dark theme"
        title="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
