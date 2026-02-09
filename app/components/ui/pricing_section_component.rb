
module UI
  ##
  # A pricing section component that wraps pricing cards with a monthly/yearly toggle.
  #
  # This component renders a section with title, subtitle, a billing period toggle (monthly/yearly),
  # and yields to a block where pricing cards should be rendered. The component applies the `group`
  # class to enable child components (like PricingCardComponent) to react to the toggle state.
  #
  # The toggle uses radio buttons with name="billing-period". The first radio (Monthly) is checked
  # by default. Child components can use `group-has-[:checked]:hidden` to show monthly pricing by
  # default, and `hidden group-has-[:checked]:block` to show yearly pricing when toggled.
  #
  # @example With pricing cards
  #   <%= render UI::PricingSectionComponent.new(
  #     title: "Pricing Plans",
  #     subtitle: "Choose the plan that fits your agency's needs"
  #   ) do %>
  #     <div class="grid gap-6 md:grid-cols-3">
  #       <%= render UI::PricingCardComponent.new(...) %>
  #       <%= render UI::PricingCardComponent.new(...) %>
  #       <%= render UI::PricingCardComponent.new(...) %>
  #     </div>
  #   <% end %>
  #
  class PricingSectionComponent < ViewComponent::Base
    def initialize(title:, subtitle:, **kwargs)
      @title = title
      @subtitle = subtitle
      @kwargs = kwargs
    end
  end
end
