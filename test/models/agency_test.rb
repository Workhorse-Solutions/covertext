require "test_helper"

class AgencyTest < ActiveSupport::TestCase
  test "requires name" do
    agency = Agency.new(phone_sms: "+15559999999", account: accounts(:reliable_group))
    assert_not agency.valid?
    assert_includes agency.errors[:name], "can't be blank"
  end

  test "requires account" do
    agency = Agency.new(name: "Test Agency", phone_sms: "+15559999999")
    assert_not agency.valid?
    assert_includes agency.errors[:account], "must exist"
  end

  test "requires unique phone_sms" do
    duplicate = Agency.new(
      name: "Duplicate Agency",
      phone_sms: agencies(:reliable).phone_sms,
      account: accounts(:reliable_group)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:phone_sms], "has already been taken"
  end

  test "creates agency with valid attributes" do
    agency = Agency.new(
      name: "Valid Agency",
      phone_sms: "+15559999999",
      account: accounts(:reliable_group)
    )
    assert agency.valid?
    assert agency.save
  end

  test "settings defaults to empty hash" do
    agency = Agency.create!(
      name: "Test Agency",
      phone_sms: "+15558888888",
      account: accounts(:reliable_group)
    )
    assert_equal({}, agency.settings)
  end

  test "live_enabled defaults to false" do
    agency = Agency.create!(
      name: "Test Agency",
      phone_sms: "+15557777777",
      account: accounts(:reliable_group)
    )
    assert_equal false, agency.live_enabled
  end

  test "active defaults to true" do
    agency = Agency.create!(
      name: "Test Agency",
      phone_sms: "+15556666666",
      account: accounts(:reliable_group)
    )
    assert agency.active?
  end

  test "belongs_to account" do
    agency = agencies(:reliable)
    assert_instance_of Account, agency.account
    assert_equal accounts(:reliable_group), agency.account
  end

  test "can_go_live? requires active agency, active subscription, and live_enabled" do
    agency = agencies(:reliable)
    account = agency.account

    # All conditions met
    account.update!(subscription_status: "active")
    agency.update!(active: true, live_enabled: true)
    assert agency.can_go_live?

    # Missing live_enabled
    agency.update!(live_enabled: false)
    assert_not agency.can_go_live?

    # Missing active
    agency.update!(live_enabled: true, active: false)
    assert_not agency.can_go_live?

    # Missing subscription
    agency.update!(active: true)
    account.update!(subscription_status: "past_due")
    assert_not agency.can_go_live?
  end

  test "activate! sets active to true" do
    agency = agencies(:reliable)
    agency.update!(active: false)
    assert_not agency.active?

    agency.activate!

    assert agency.active?
    assert agency.reload.active?
  end

  test "deactivate! sets active to false" do
    agency = agencies(:reliable)
    agency.update!(active: true)
    assert agency.active?

    agency.deactivate!

    assert_not agency.active?
    assert_not agency.reload.active?
  end
end
