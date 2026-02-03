# frozen_string_literal: true

module RegistrationsHelper
  def selected_plan
    @selected_plan ||= begin
      plan = params[:plan]&.to_sym
      Plan.valid?(plan) ? plan : Plan.default
    end
  end

  def plan_info
    @plan_info ||= Plan.info(selected_plan)
  end
end
