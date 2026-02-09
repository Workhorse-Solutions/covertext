
require "test_helper"

class UI::FeatureItemComponentTest < ViewComponent::TestCase
  test "renders with icon, title, and description" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Feature Title", description: "Feature description"))

    assert_selector "div.flex.items-start.gap-4"
    assert_selector "div.text-2xl", text: "✅"
    assert_selector "h4.font-bold.text-lg", text: "Feature Title"
    assert_selector "p.text-base-content\\/70", text: "Feature description"
  end

  test "renders with icon and title only" do
    render_inline(UI::FeatureItemComponent.new(icon: "🔒", title: "Security"))

    assert_selector "h4", text: "Security"
    assert_no_selector "p"
  end

  test "renders with icon and description only" do
    render_inline(UI::FeatureItemComponent.new(icon: "❌", description: "Not supported"))

    assert_selector "p", text: "Not supported"
    assert_no_selector "h4"
  end

  test "renders with icon and block content" do
    render_inline(UI::FeatureItemComponent.new(icon: "🚀")) { "<strong>Custom</strong> content".html_safe }

    assert_selector "div.text-2xl", text: "🚀"
    assert_selector "strong", text: "Custom"
  end

  test "customizes gap size" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Test", gap: "gap-8"))

    assert_selector "div.flex.items-start.gap-8"
    assert_no_selector "div.gap-4"
  end

  test "customizes icon size" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Test", icon_size: "text-xl"))

    assert_selector "div.text-xl", text: "✅"
    assert_no_selector "div.text-2xl"
  end

  test "adds extra classes to outer container" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Test", class_name: "mb-4"))

    assert_selector "div.flex.items-start.gap-4.mb-4"
  end

  test "adds extra classes to title" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Test", title_class: "text-primary"))

    assert_selector "h4.font-bold.text-lg.text-primary"
  end

  test "adds extra classes to description" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", description: "Test", description_class: "text-sm"))

    assert_selector "p.text-base-content\\/70.text-sm"
  end

  test "passes through html attributes" do
    render_inline(UI::FeatureItemComponent.new(icon: "✅", title: "Test", id: "feature-1", data: { feature: "main" }))

    assert_selector 'div#feature-1[data-feature="main"]'
  end

  test "renders with heroicon" do
    render_inline(UI::FeatureItemComponent.new(icon: "check-circle", icon_type: :heroicon, title: "Success"))

    assert_selector "svg"
    assert_selector "h4", text: "Success"
  end

  test "renders with heroicon outline variant" do
    render_inline(UI::FeatureItemComponent.new(icon: "check-circle", icon_type: :heroicon, icon_variant: :outline, title: "Success"))

    assert_selector "svg"
  end

  test "renders with heroicon mini variant" do
    render_inline(UI::FeatureItemComponent.new(icon: "check-circle", icon_type: :heroicon, icon_variant: :mini, title: "Success"))

    assert_selector "svg"
  end
end
