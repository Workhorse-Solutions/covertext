
require "test_helper"

class UI::StepComponentTest < ViewComponent::TestCase
  test "renders with number, title, and description" do
    render_inline(UI::StepComponent.new(number: 1, title: "First Step", description: "Do this first"))

    assert_selector "div.text-center"
    assert_selector "div.w-16.h-16.rounded-full.bg-primary.text-primary-content", text: "1"
    assert_selector "h4.font-bold.mb-2", text: "First Step"
    assert_selector "p.text-sm.text-base-content\\/70", text: "Do this first"
  end

  test "renders with string number" do
    render_inline(UI::StepComponent.new(number: "A", title: "Step A", description: "First step"))

    assert_selector "div.rounded-full", text: "A"
  end

  test "renders with title only" do
    render_inline(UI::StepComponent.new(number: 1, title: "Step Title"))

    assert_selector "h4", text: "Step Title"
    assert_no_selector "p"
  end

  test "renders with block content instead of description" do
    render_inline(UI::StepComponent.new(number: 1, title: "Custom")) { "<strong>Custom</strong> content".html_safe }

    assert_selector "strong", text: "Custom"
  end

  test "customizes badge color" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", badge_color: "bg-secondary"))

    assert_selector "div.bg-secondary.text-primary-content"
    assert_no_selector "div.bg-primary"
  end

  test "adds extra classes to outer container" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", class_name: "mt-4"))

    assert_selector "div.text-center.mt-4"
  end

  test "adds extra classes to badge" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", badge_class: "shadow-lg"))

    assert_selector "div.rounded-full.shadow-lg"
  end

  test "adds extra classes to title" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", title_class: "text-xl"))

    assert_selector "h4.font-bold.mb-2.text-xl"
  end

  test "adds extra classes to description" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", description: "Desc", description_class: "text-base"))

    assert_selector "p.text-sm.text-base-content\\/70.text-base"
  end

  test "passes through html attributes" do
    render_inline(UI::StepComponent.new(number: 1, title: "Test", id: "step-1", data: { step: "first" }))

    assert_selector 'div#step-1[data-step="first"]'
  end
end
