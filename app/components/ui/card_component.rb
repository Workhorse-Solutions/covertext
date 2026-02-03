class UI::CardComponent < ViewComponent::Base
  DEFAULT_OUTER_CLASSES = "card bg-base-100 border-gray-200 border shadow".freeze
  DEFAULT_BODY_CLASSES  = "card-body".freeze

  # @param class_name [String, nil] extra classes for the outer card container
  # @param body_class [String, nil] extra classes for the inner card body
  # @param outer_class [String, nil] full override for outer classes (use sparingly)
  # @param tag [Symbol] wrapper tag for the outer container
  # @param kwargs [Hash] any extra HTML attributes for the outer container (id, data, aria, etc.)
  def initialize(class_name: nil, body_class: nil, outer_class: nil, tag: :div, **kwargs)
    @class_name = class_name
    @body_class = body_class
    @outer_class = outer_class
    @tag = tag
    @kwargs = kwargs
  end

  private

  attr_reader :class_name, :body_class, :outer_class, :tag, :kwargs

  def outer_classes
    if outer_class.present?
      outer_class
    else
      [ DEFAULT_OUTER_CLASSES, class_name ].compact.join(" ")
    end
  end

  def body_classes
    [ DEFAULT_BODY_CLASSES, body_class ].compact.join(" ")
  end
end
