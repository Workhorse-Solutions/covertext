require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "requires name" do
    account = Account.new
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "creates account with valid attributes" do
    account = Account.new(name: "Test Account")
    assert account.valid?
    assert account.save
  end

  test "requires unique stripe_customer_id" do
    Account.create!(name: "First Account", stripe_customer_id: "cus_123")
    duplicate = Account.new(name: "Second Account", stripe_customer_id: "cus_123")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:stripe_customer_id], "has already been taken"
  end

  test "allows nil stripe_customer_id" do
    account = Account.new(name: "Account Without Stripe", stripe_customer_id: nil)
    assert account.valid?
  end

  test "requires unique stripe_subscription_id" do
    Account.create!(name: "First Account", stripe_subscription_id: "sub_123")
    duplicate = Account.new(name: "Second Account", stripe_subscription_id: "sub_123")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:stripe_subscription_id], "has already been taken"
  end

  test "allows nil stripe_subscription_id" do
    account = Account.new(name: "Account Without Stripe", stripe_subscription_id: nil)
    assert account.valid?
  end

  test "validates subscription_status inclusion" do
    account = Account.new(name: "Test Account", subscription_status: "invalid_status")
    assert_not account.valid?
    assert_includes account.errors[:subscription_status], "is not included in the list"
  end

  test "allows valid subscription_status values" do
    %w[active canceled incomplete incomplete_expired past_due trialing unpaid paused].each do |status|
      account = Account.new(name: "Test Account", subscription_status: status)
      assert account.valid?, "Expected subscription_status '#{status}' to be valid"
    end
  end

  test "allows nil subscription_status" do
    account = Account.new(name: "Test Account", subscription_status: nil)
    assert account.valid?
  end

  test "has_many agencies" do
    assert Account.reflect_on_association(:agencies).macro == :has_many
  end

  test "has_many users" do
    assert Account.reflect_on_association(:users).macro == :has_many
  end

  # subscription_active? tests
  test "subscription_active? returns true when status is active" do
    account = Account.new(name: "Test", subscription_status: "active")
    assert account.subscription_active?
  end

  test "subscription_active? returns false when status is not active" do
    %w[canceled incomplete past_due trialing unpaid paused].each do |status|
      account = Account.new(name: "Test", subscription_status: status)
      assert_not account.subscription_active?, "Expected subscription_active? to be false for status '#{status}'"
    end
  end

  test "subscription_active? returns false when status is nil" do
    account = Account.new(name: "Test", subscription_status: nil)
    assert_not account.subscription_active?
  end

  # has_active_agency? tests
  test "has_active_agency? returns true when at least one agency is active" do
    account = accounts(:reliable_group)
    assert account.has_active_agency?
  end

  test "has_active_agency? returns false when no agencies exist" do
    account = Account.create!(name: "Empty Account")
    assert_not account.has_active_agency?
  end

  test "has_active_agency? returns false when all agencies are inactive" do
    account = Account.create!(name: "Inactive Agencies Account")
    account.agencies.create!(name: "Inactive Agency", phone_sms: "+15550001234", active: false)
    assert_not account.has_active_agency?
  end

  # can_access_system? tests
  test "can_access_system? returns true when subscription active and has active agency" do
    account = accounts(:reliable_group)
    assert account.subscription_active?
    assert account.has_active_agency?
    assert account.can_access_system?
  end

  test "can_access_system? returns false when subscription not active" do
    account = accounts(:reliable_group)
    account.subscription_status = "canceled"
    assert_not account.can_access_system?
  end

  test "can_access_system? returns false when no active agencies" do
    account = Account.create!(name: "No Agencies", subscription_status: "active")
    assert account.subscription_active?
    assert_not account.has_active_agency?
    assert_not account.can_access_system?
  end

  # owner tests
  test "owner returns user with owner role" do
    account = accounts(:reliable_group)
    owner = account.owner
    assert_not_nil owner
    assert_equal "owner", owner.role
    assert_equal users(:john_owner), owner
  end

  test "owner returns nil when no owner exists" do
    account = Account.create!(name: "No Owner Account")
    assert_nil account.owner
  end

  # in_grace_period? tests
  test "in_grace_period? returns true when canceled with future end date within 14 days" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 7.days.from_now
    )
    assert account.in_grace_period?
  end

  test "in_grace_period? returns false when subscription is active" do
    account = Account.new(
      name: "Test",
      subscription_status: "active",
      subscription_ends_at: 7.days.from_now
    )
    assert_not account.in_grace_period?
  end

  test "in_grace_period? returns false when subscription_ends_at is nil" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: nil
    )
    assert_not account.in_grace_period?
  end

  test "in_grace_period? returns false when subscription_ends_at is in the past" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 1.day.ago
    )
    assert_not account.in_grace_period?
  end

  test "in_grace_period? returns false when subscription_ends_at is beyond 14 days" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 15.days.from_now
    )
    assert_not account.in_grace_period?
  end

  # read_only? tests
  test "read_only? returns true when in grace period" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 7.days.from_now
    )
    assert account.read_only?
  end

  test "read_only? returns false when subscription is active" do
    account = Account.new(
      name: "Test",
      subscription_status: "active"
    )
    assert_not account.read_only?
  end

  # days_until_lockout tests
  test "days_until_lockout returns days remaining when in grace period" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 7.days.from_now
    )
    assert_equal 7, account.days_until_lockout
  end

  test "days_until_lockout returns 1 when less than 1 day remains" do
    account = Account.new(
      name: "Test",
      subscription_status: "canceled",
      subscription_ends_at: 12.hours.from_now
    )
    assert_equal 1, account.days_until_lockout
  end

  test "days_until_lockout returns nil when not in grace period" do
    account = Account.new(
      name: "Test",
      subscription_status: "active"
    )
    assert_nil account.days_until_lockout
  end

  # can_access_system? with grace period tests
  test "can_access_system? returns true during grace period with active agency" do
    account = accounts(:reliable_group)
    account.subscription_status = "canceled"
    account.subscription_ends_at = 7.days.from_now
    assert account.in_grace_period?
    assert account.has_active_agency?
    assert account.can_access_system?
  end

  test "can_access_system? returns false after grace period expires" do
    account = accounts(:reliable_group)
    account.subscription_status = "canceled"
    account.subscription_ends_at = 1.day.ago
    assert_not account.can_access_system?
  end
end
