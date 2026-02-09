
module UI
  ##
  # A pricing card component that displays tier information with monthly/yearly pricing toggle.
  #
  # This component is designed to work with a parent container that has the `group` class
  # and contains radio buttons with name="billing-period". The first radio (monthly) should
  # be checked by default. The component uses Tailwind's `group-has-[:checked]` selector
  # to toggle between monthly and yearly pricing displays.
  #
  # @example Basic usage
  #   <%= render UI::PricingCardComponent.new(
  #     tier: "Premium",
  #     badge_text: "Most Popular",
  #     badge_style: "badge-primary",
  #     monthly_price: 99,
  #     yearly_price: 950,
  #     yearly_savings: "save $238",
  #     features: ["Unlimited texts", "Up to 3 locations", "Priority support"],
  #     cta_text: "Start Free Trial",
  #     cta_url: "#",
  #     cta_primary: true
  #   ) %>
  #
  # @example Free tier (same monthly/yearly price)
  #   <%= render UI::PricingCardComponent.new(
  #     tier: "Free",
  #     badge_text: "Get Started",
  #     badge_style: "badge-ghost",
  #     monthly_price: 0,
  #     yearly_price: 0,
  #     features: ["Up to 50 texts/month", "1 agency location"],
  #     cta_text: "Get Started",
  #     cta_url: "#",
  #     cta_primary: false
  #   ) %>
  #
  class PricingCardComponent < ViewComponent::Base
    def initialize(
      tier:,
      badge_text:,
      badge_style: "badge-ghost",
      monthly_price:,
      yearly_price:,
      yearly_savings: nil,
      description: nil,
      features:,
      cta_text:,
      cta_url:,
      cta_primary: false,
      header_bg: "bg-base-200",
      header_color: nil,
      price_size: "text-5xl"
    )
      @tier = tier
      @badge_text = badge_text
      @badge_style = badge_style
      @monthly_price = monthly_price
      @yearly_price = yearly_price
      @yearly_savings = yearly_savings
      @description = description
      @features = features
      @cta_text = cta_text
      @cta_url = cta_url
      @cta_primary = cta_primary
      @header_bg = header_bg
      @header_color = header_color
      @price_size = price_size
    end

    def monthly_price_display
      "$#{@monthly_price}"
    end

    def yearly_price_display
      "$#{@yearly_price}"
    end

    def cta_classes
      base = "btn btn-block mt-auto"
      if @cta_primary
        tier_color = @header_color&.sub("text-", "btn-") || "btn-primary"
        "#{base} #{tier_color}"
      else
        "#{base} btn-outline border-base-300"
      end
    end

    def header_classes
      classes = [ @header_bg, "rounded-box p-6" ]
      classes.compact.join(" ")
    end

    def tier_classes
      classes = [ @header_color, "text-xl font-semibold" ]
      classes.compact.join(" ")
    end

    def price_classes
      classes = [ @header_color, @price_size, "font-semibold tracking-tight" ]
      classes.compact.join(" ")
    end
  end
end
