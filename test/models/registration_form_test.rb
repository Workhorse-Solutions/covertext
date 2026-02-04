require "test_helper"

class RegistrationFormTest < ActiveSupport::TestCase
  test "validates presence of all required fields" do
    form = RegistrationForm.new
    assert_not form.valid?
    assert_includes form.errors[:account_name], "can't be blank"
    assert_includes form.errors[:plan_tier], "can't be blank"
    assert_includes form.errors[:agency_name], "can't be blank"
    assert_includes form.errors[:user_first_name], "can't be blank"
    assert_includes form.errors[:user_last_name], "can't be blank"
    assert_includes form.errors[:user_email], "can't be blank"
    assert_includes form.errors[:user_password], "can't be blank"
  end

  test "validates plan_tier is valid" do
    form = RegistrationForm.new(plan_tier: "invalid")
    assert_not form.valid?
    assert_includes form.errors[:plan_tier], "is not included in the list"
  end

  test "validates user_email format" do
    form = RegistrationForm.new(user_email: "invalid")
    assert_not form.valid?
    assert_includes form.errors[:user_email], "is invalid"
  end

  test "validates user_password minimum length" do
    form = RegistrationForm.new(user_password: "short")
    assert_not form.valid?
    assert_includes form.errors[:user_password], "is too short (minimum is 8 characters)"
  end

  test "validates user_email uniqueness" do
    form = RegistrationForm.new(
      account_name: "Test Account",
      plan_tier: "starter",
      agency_name: "Test Agency",
      user_first_name: "John",
      user_last_name: "Doe",
      user_email: users(:john_owner).email,
      user_password: "password123"
    )
    assert_not form.valid?
    assert_includes form.errors[:user_email], "has already been taken"
  end

  test "save creates Account, Agency, and User" do
    form = RegistrationForm.new(
      account_name: "New Test Account",
      plan_tier: "professional",
      agency_name: "New Test Agency",
      user_first_name: "Jane",
      user_last_name: "Smith",
      user_email: "jane.smith@newtest.com",
      user_password: "securepass123"
    )

    assert_difference [ "Account.count", "Agency.count", "User.count" ], 1 do
      assert form.save
    end

    assert form.account.persisted?
    assert_equal "New Test Account", form.account.name
    assert form.account.professional?

    assert form.agency.persisted?
    assert_equal "New Test Agency", form.agency.name
    assert_nil form.agency.phone_sms
    assert form.agency.active?
    assert_equal false, form.agency.live_enabled

    assert form.user.persisted?
    assert_equal "Jane", form.user.first_name
    assert_equal "Smith", form.user.last_name
    assert_equal "jane.smith@newtest.com", form.user.email
    assert_equal "owner", form.user.role
  end

  test "save returns false when validation fails" do
    form = RegistrationForm.new(account_name: "")
    assert_not form.save
    assert form.errors.any?
  end

  test "save rolls back transaction on error" do
    form = RegistrationForm.new(
      account_name: "Rollback Test",
      plan_tier: "starter",
      agency_name: "Rollback Agency",
      user_first_name: "Test",
      user_last_name: "User",
      user_email: "invalid-email",
      user_password: "password123"
    )

    assert_no_difference [ "Account.count", "Agency.count", "User.count" ] do
      form.save
    end
  end
end
