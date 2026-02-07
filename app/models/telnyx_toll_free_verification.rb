class TelnyxTollFreeVerification < ApplicationRecord
  belongs_to :agency

  STATUSES = %w[draft submitted in_review waiting_for_customer approved rejected].freeze

  validates :agency, presence: true
  validates :telnyx_number, presence: true, uniqueness: { scope: :agency_id }
  validates :status, presence: true, inclusion: { in: STATUSES }

  def draft?
    status == "draft"
  end

  def submitted?
    status == "submitted"
  end

  def in_review?
    status == "in_review"
  end

  def waiting_for_customer?
    status == "waiting_for_customer"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def terminal?
    approved? || rejected?
  end
end
