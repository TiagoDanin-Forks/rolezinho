defmodule Storybook.UI do
  use PhoenixStorybook.Index

  def folder_name, do: "Components"
  def folder_open?, do: true
  def folder_icon, do: {:fa, "shapes", :thin}

  def entry("button"), do: [icon: {:fa, "rectangle-ad", :thin}]
  def entry("icon_button"), do: [icon: {:fa, "circle-arrow-left", :thin}]
  def entry("fab"), do: [icon: {:fa, "circle-plus", :thin}]
  def entry("avatar"), do: [icon: {:fa, "circle-user", :thin}]
  def entry("avatar_stack"), do: [icon: {:fa, "users-line", :thin}]
  def entry("progress_bar"), do: [icon: {:fa, "bars-progress", :thin}]
  def entry("payment_legend"), do: [icon: {:fa, "circle-check", :thin}]
  def entry("status_pill"), do: [icon: {:fa, "certificate", :thin}]
  def entry("info_tile"), do: [icon: {:fa, "receipt", :thin}]
  def entry("detail_row"), do: [icon: {:fa, "location-dot", :thin}]
  def entry("section_header"), do: [icon: {:fa, "heading", :thin}]
  def entry("participant_row"), do: [icon: {:fa, "list-ol", :thin}]
  def entry("text_field"), do: [icon: {:fa, "input-text", :thin}]
  def entry("password_field"), do: [icon: {:fa, "key", :thin}]
  def entry("stepper"), do: [icon: {:fa, "plus-minus", :thin}]
  def entry("segmented_control"), do: [icon: {:fa, "table-columns", :thin}]
  def entry("toggle_chip"), do: [icon: {:fa, "toggle-on", :thin}]
  def entry("bottom_sheet"), do: [icon: {:fa, "window-maximize", :thin}]
  def entry("toast"), do: [icon: {:fa, "message", :thin}]
  def entry("alert_banner"), do: [icon: {:fa, "triangle-exclamation", :thin}]
  def entry("empty_state"), do: [icon: {:fa, "inbox", :thin}]
  def entry("skeleton"), do: [icon: {:fa, "bars", :thin}]
  def entry("share_preview"), do: [icon: {:fa, "share-nodes", :thin}]
  def entry("event_card"), do: [icon: {:fa, "square", :thin}]
  def entry("card"), do: [icon: {:fa, "square-full", :thin}]
  def entry("well"), do: [icon: {:fa, "square-dashed", :thin}]
end
