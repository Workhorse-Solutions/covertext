
class UI::FeatureItemComponent < ViewComponent::Base
  DEFAULT_CLASSES = "flex items-start".freeze
  DEFAULT_GAP = "gap-4".freeze
  DEFAULT_ICON_SIZE = "text-2xl".freeze

  # Feature item component with icon, title, and description or custom content.
  #
  # @param icon [String] emoji, unicode character, or heroicon name
  #   Examples:
  #     icon: "✅"                  # Emoji (copy from https://emojipedia.org)
  #     icon: "\u2705"              # Unicode (find codes at https://unicode-table.com)
  #     icon: "check-circle"        # Heroicon name (see https://heroicons.com)
  # @param icon_type [Symbol] :emoji (default) or :heroicon
  # @param icon_variant [Symbol] heroicon variant - :solid (default), :outline, or :mini
  # @param title [String, nil] optional heading text
  # @param description [String, nil] optional description text (alternative to block)
  # @param gap [String] gap size between icon and content (default: "gap-4")
  # @param icon_size [String] icon text size for emoji/unicode (default: "text-2xl", ignored for heroicons)
  # @param class_name [String, nil] extra classes for the outer container
  # @param title_class [String, nil] extra classes for the title element
  # @param description_class [String, nil] extra classes for the description element
  # @param kwargs [Hash] any extra HTML attributes for the outer container (id, data, aria, etc.)
  def initialize(
    icon:,
    icon_type: :emoji,
    icon_variant: :solid,
    title: nil,
    description: nil,
    gap: DEFAULT_GAP,
    icon_size: DEFAULT_ICON_SIZE,
    class_name: nil,
    title_class: nil,
    description_class: nil,
    **kwargs
  )
    @icon = icon
    @icon_type = icon_type
    @icon_variant = icon_variant
    @title = title
    @description = description
    @gap = gap
    @icon_size = icon_size
    @class_name = class_name
    @title_class = title_class
    @description_class = description_class
    @kwargs = kwargs
  end

  private

  attr_reader :icon, :icon_type, :icon_variant, :title, :description, :gap, :icon_size, :class_name, :title_class, :description_class, :kwargs

  def outer_classes
    [ DEFAULT_CLASSES, gap, class_name ].compact.join(" ")
  end

  def icon_classes
    icon_type == :heroicon ? "" : icon_size
  end

  def render_icon
    if icon_type == :heroicon
      helpers.heroicon(icon, variant: icon_variant)
    else
      icon
    end
  end

  def title_classes
    [ "font-bold text-lg", title_class ].compact.join(" ")
  end

  def description_classes
    [ "text-base-content/70", description_class ].compact.join(" ")
  end

  def has_content?
    title.present? || description.present? || content?
  end
end
