
class UI::StepComponent < ViewComponent::Base
  DEFAULT_CLASSES = "text-center".freeze
  DEFAULT_BADGE_CLASSES = "w-16 h-16 rounded-full bg-primary text-primary-content flex items-center justify-center text-2xl font-bold mx-auto mb-4".freeze
  DEFAULT_TITLE_CLASSES = "font-bold mb-2".freeze
  DEFAULT_DESCRIPTION_CLASSES = "text-sm text-base-content/70".freeze

  # Step component for multi-step processes, instructions, or workflows.
  #
  # @param number [Integer, String] step number or label to display in badge
  # @param title [String] step title/heading
  # @param description [String, nil] optional description text (alternative to block)
  # @param badge_color [String, nil] custom background color class for badge (e.g., "bg-secondary")
  # @param class_name [String, nil] extra classes for the outer container
  # @param badge_class [String, nil] extra classes for the badge element
  # @param title_class [String, nil] extra classes for the title element
  # @param description_class [String, nil] extra classes for the description element
  # @param kwargs [Hash] any extra HTML attributes for the outer container (id, data, aria, etc.)
  def initialize(
    number:,
    title:,
    description: nil,
    badge_color: nil,
    class_name: nil,
    badge_class: nil,
    title_class: nil,
    description_class: nil,
    **kwargs
  )
    @number = number
    @title = title
    @description = description
    @badge_color = badge_color
    @class_name = class_name
    @badge_class = badge_class
    @title_class = title_class
    @description_class = description_class
    @kwargs = kwargs
  end

  private

  attr_reader :number, :title, :description, :badge_color, :class_name, :badge_class, :title_class, :description_class, :kwargs

  def outer_classes
    [ DEFAULT_CLASSES, class_name ].compact.join(" ")
  end

  def badge_classes
    classes = DEFAULT_BADGE_CLASSES.dup
    if badge_color.present?
      # Replace default bg-primary with custom color
      classes = classes.gsub(/bg-primary/, badge_color)
    end
    [ classes, badge_class ].compact.join(" ")
  end

  def title_classes
    [ DEFAULT_TITLE_CLASSES, title_class ].compact.join(" ")
  end

  def description_classes
    [ DEFAULT_DESCRIPTION_CLASSES, description_class ].compact.join(" ")
  end
end
