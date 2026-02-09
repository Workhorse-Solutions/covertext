
module UI
  module Form
    ##
    # A billing interval toggle component for switching between monthly and yearly billing.
    # Uses DaisyUI tabs styling consistently across marketing and signup pages.
    #
    # @example Basic usage (marketing page)
    #   <%= render UI::Form::BillingIntervalToggleComponent.new(
    #     selected: :yearly,
    #     show_badge: true,
    #     data: { action: "change->pricing#updateAllUrls" }
    #   ) %>
    #
    # @example With price display (signup form)
    #   <%= render UI::Form::BillingIntervalToggleComponent.new(
    #     name: "billing_interval",
    #     selected: :yearly,
    #     show_badge: true,
    #     data: {
    #       controller: "billing-interval",
    #       billing_interval_monthly_price_value: 99,
    #       billing_interval_yearly_price_value: 950,
    #       action: "change->billing-interval#updatePrice"
    #     }
    #   ) do |c| %>
    #     <%= c.with_price_display do %>
    #       <p class="mt-2 text-center text-2xl font-bold" data-billing-interval-target="priceDisplay">
    #         $950/year
    #       </p>
    #     <% end %>
    #   <% end %>
    #
    class BillingIntervalToggleComponent < ViewComponent::Base
      renders_one :price_display

      def initialize(
        name: "pricing-tab",
        selected: :yearly,
        show_badge: true,
        badge_text: "2 months Free",
        data: {}
      )
        @name = name
        @selected = selected.to_sym
        @show_badge = show_badge
        @badge_text = badge_text
        @data = data
      end

      def monthly_checked?
        @selected == :monthly
      end

      def yearly_checked?
        @selected == :yearly
      end

      def data_action_attr
        @data[:action] if @data[:action]
      end
    end
  end
end
