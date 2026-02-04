class UI::Form::FieldComponent < ViewComponent::Base
  renders_one :input

  def initialize(form:, attribute:, label: nil, hint: nil)
    @form = form
    @attribute = attribute
    @label = label
    @hint = hint
  end

  def invalid?
    form.object&.errors&.[](attribute)&.present? || false
  end

  def error_messages
    form.object&.errors&.full_messages_for(attribute) || []
  end

  private

  attr_reader :form, :attribute, :label, :hint
end
