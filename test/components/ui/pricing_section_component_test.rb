
require "test_helper"

module UI
  class PricingSectionComponentTest < ViewComponent::TestCase
    test "renders title" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      ))

      assert_selector "h2", text: "Pricing Plans"
    end

    test "renders subtitle" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose the plan that fits your agency's needs"
      ))

      assert_selector "p", text: "Choose the plan that fits your agency's needs"
    end

    test "renders monthly/yearly toggle with radio buttons" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      ))

      assert_selector "input[type='radio'][name='pricing-tab'][value='monthly'][aria-label='Monthly']"
      assert_selector "input[type='radio'][name='pricing-tab'][value='yearly'][aria-label='Yearly'][checked]"
    end

    test "renders block content" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      )) do
        "<div class='pricing-cards'>Card Content</div>".html_safe
      end

      assert_selector ".pricing-cards", text: "Card Content"
    end

    test "wraps content in UI::SectionComponent with group class" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan",
        id: "pricing"
      ))

      assert_selector "section#pricing"
      assert_selector ".group"
    end

    test "applies proper spacing classes" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      ))

      assert_selector "section.py-8.lg\\:py-20"
    end

    test "centers title and subtitle" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      ))

      assert_selector ".text-center h2", text: "Pricing Plans"
      assert_selector ".text-center p", text: "Choose your plan"
    end

    test "renders toggle in centered tabs container" do
      render_inline(PricingSectionComponent.new(
        title: "Pricing Plans",
        subtitle: "Choose your plan"
      ))

      assert_selector ".flex.justify-center .tabs.tabs-box"
      assert_selector ".tabs input.tab[type='radio']", count: 2
    end
  end
end
