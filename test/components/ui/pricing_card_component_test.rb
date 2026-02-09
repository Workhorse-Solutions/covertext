
require "test_helper"

module UI
  class PricingCardComponentTest < ViewComponent::TestCase
    test "renders tier name" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "h3", text: "Premium"
    end

    test "renders badge with custom style" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        badge_style: "badge-primary",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector ".badge.badge-primary", text: "Most Popular"
    end

    test "renders monthly price with data value" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "data[value='99']", text: "$99"
      assert_text "/month"
    end

    test "renders yearly price with data value" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "data[value='950']", text: "$950"
      assert_text "/month"  # Both prices show /month
    end

    test "renders description when provided" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        description: "Unlock advanced features and elevate your experience.",
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_text "Unlock advanced features and elevate your experience."
    end

    test "does not render description when not provided" do
      render_inline(PricingCardComponent.new(
        tier: "Free",
        badge_text: "Get Started",
        monthly_price: 0,
        yearly_price: 0,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      # Should not have a description paragraph in header
      assert_selector ".rounded-box p", count: 1  # Only the price paragraph
    end

    test "renders all features with bullet points" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Unlimited texts", "Priority support", "Custom branding" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "li", count: 3
      assert_text "Unlimited texts"
      assert_text "Priority support"
      assert_text "Custom branding"
    end

    test "renders CTA as primary button when cta_primary is true" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Start Free Trial",
        cta_url: "/signup",
        cta_primary: true
      ))

      assert_selector "a.btn.btn-primary[href='/signup']", text: "Start Free Trial"
    end

    test "renders CTA as outline button when cta_primary is false" do
      render_inline(PricingCardComponent.new(
        tier: "Free",
        badge_text: "Get Started",
        monthly_price: 0,
        yearly_price: 0,
        features: [ "Feature 1" ],
        cta_text: "Get Started",
        cta_url: "/signup",
        cta_primary: false
      ))

      assert_selector "a.btn.btn-outline[href='/signup']", text: "Get Started"
    end

    test "renders tier name without inline badge when badge_style is badge-ghost" do
      render_inline(PricingCardComponent.new(
        tier: "Free",
        badge_text: "Get Started",
        monthly_price: 0,
        yearly_price: 0,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "h3", text: "Free"
      # Badge-ghost style means no inline badge in header
      refute_selector ".rounded-box .badge"
    end

    test "defaults cta_primary to false (outline button)" do
      render_inline(PricingCardComponent.new(
        tier: "Free",
        badge_text: "Get Started",
        monthly_price: 0,
        yearly_price: 0,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector "a.btn.btn-outline"
      refute_selector "a.btn.btn-primary"
    end

    test "wraps content in UI::CardComponent" do
      render_inline(PricingCardComponent.new(
        tier: "Premium",
        badge_text: "Most Popular",
        monthly_price: 99,
        yearly_price: 950,
        features: [ "Feature 1" ],
        cta_text: "Sign Up",
        cta_url: "#"
      ))

      assert_selector ".card.border-base-300"
      assert_selector ".card-body"
    end
  end
end
