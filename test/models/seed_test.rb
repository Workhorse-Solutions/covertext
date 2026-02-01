require "test_helper"

class SeedTest < ActiveSupport::TestCase
  test "seeds run without errors and create expected data" do
    # Clear existing data
    [ AuditEvent, Delivery, MessageLog, Request, Document, Policy, Client, ConversationSession, User, Agency, Account ].each(&:destroy_all)

    # Run seeds
    assert_nothing_raised do
      load Rails.root.join("db/seeds.rb")
    end

    # Verify expected counts - multitenancy model: 1 Account with 2 Agencies
    assert_equal 1, Account.count, "Should create 1 account"
    assert_equal 2, Agency.count, "Should create 2 agencies"
    assert_equal 1, User.count, "Should create 1 user"
    assert_equal 4, Client.count, "Should create 4 clients (2 per agency)"
    assert_equal 10, Policy.count, "Should create 10 policies"
    assert_equal 10, Document.count, "Should create 10 documents"

    # Verify all documents have attached files
    assert_equal 10, Document.joins(:file_attachment).count, "All documents should have files attached"

    # Verify agencies have valid phone numbers and belong to account
    account = Account.first
    assert_equal 2, account.agencies.count, "Account should have 2 agencies"
    account.agencies.each do |agency|
      assert agency.phone_sms.present?
      assert agency.phone_sms.start_with?("+1")
      assert agency.active?, "Agency should be active"
    end

    # Verify user belongs to account with owner role
    user = User.first
    assert_equal account, user.account
    assert_equal "owner", user.role
  end
end
