require "test_helper"

class UI::CardComponentTest < ViewComponent::TestCase
  test "renders default outer and body classes" do
    render_inline(UI::CardComponent.new) { "Hello" }

    assert_selector "div.card.bg-base-100.border-gray-200.border.shadow"
    assert_selector "div.card-body", text: "Hello"
  end

  test "appends extra classes to outer and body" do
    render_inline(UI::CardComponent.new(class_name: "mt-4", body_class: "gap-4")) { "Hello" }

    assert_selector "div.card.bg-base-100.border-gray-200.border.shadow.mt-4"
    assert_selector "div.card-body.gap-4", text: "Hello"
  end

  test "outer_class fully overrides defaults" do
    render_inline(UI::CardComponent.new(outer_class: "card bg-base-200")) { "Hello" }

    assert_selector "div.card.bg-base-200"
    assert_no_selector "div.border-gray-200"
  end

  test "passes through html attributes" do
    render_inline(UI::CardComponent.new(id: "x", data: { test: "1" })) { "Hello" }

    assert_selector 'div#x[data-test="1"]'
  end

  test "renders with custom tag" do
    render_inline(UI::CardComponent.new(tag: :article)) { "Hello" }

    assert_selector "article.card.bg-base-100.border-gray-200.border.shadow"
    assert_selector "article div.card-body", text: "Hello"
  end
end
