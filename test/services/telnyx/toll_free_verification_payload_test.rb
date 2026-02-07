require "test_helper"

class Telnyx::TollFreeVerificationPayloadTest < ActiveSupport::TestCase
  setup do
    @verification = TelnyxTollFreeVerification.create!(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234",
      status: "draft"
    )

    @business_info = {
      business_name: "Reliable Insurance Agency",
      corporate_website: "https://reliableinsurance.example",
      contact_first_name: "John",
      contact_last_name: "Smith",
      contact_email: "john@reliableinsurance.example",
      contact_phone: "+15551234567",
      address1: "123 Main Street",
      address2: "Suite 100",
      city: "Denver",
      state: "Colorado",
      zip: "80202",
      country: "US",
      business_registration_number: "12-3456789",
      business_registration_type: "EIN",
      entity_type: "PRIVATE_PROFIT"
    }
  end

  test "build returns hash with all required Telnyx fields" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    # Business identity fields
    assert_equal "Reliable Insurance Agency", payload[:businessName]
    assert_equal "https://reliableinsurance.example", payload[:businessWebsite]
    assert_equal "John", payload[:businessContactFirstName]
    assert_equal "Smith", payload[:businessContactLastName]
    assert_equal "john@reliableinsurance.example", payload[:businessContactEmail]
    assert_equal "+15551234567", payload[:businessContactPhone]
    assert_equal "123 Main Street", payload[:businessAddress]
    assert_equal "Suite 100", payload[:businessAddress2]
    assert_equal "Denver", payload[:businessCity]
    assert_equal "Colorado", payload[:businessState]
    assert_equal "80202", payload[:businessZip]
    assert_equal "US", payload[:businessCountry]

    # Business registration
    assert_equal "12-3456789", payload[:businessRegistrationNumber]
    assert_equal "EIN", payload[:businessRegistrationType]
    assert_equal "US", payload[:businessRegistrationCountry]

    # Entity type
    assert_equal "PRIVATE_PROFIT", payload[:entityType]

    # Use case
    assert_equal "Insurance Services", payload[:useCase]
    assert_equal "1,000", payload[:messageVolume]

    # Phone numbers
    assert_equal [ { phoneNumber: "+18885551234" } ], payload[:phoneNumbers]
  end

  test "payload keys use camelCase" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    # Check that keys are camelCase, not snake_case
    assert payload.key?(:businessName)
    assert payload.key?(:businessWebsite)
    assert payload.key?(:businessContactFirstName)
    assert payload.key?(:businessContactLastName)
    assert payload.key?(:businessContactEmail)
    assert payload.key?(:businessContactPhone)
    assert payload.key?(:businessAddress)
    assert payload.key?(:businessAddress2)
    assert payload.key?(:businessCity)
    assert payload.key?(:businessState)
    assert payload.key?(:businessZip)
    assert payload.key?(:businessCountry)
    assert payload.key?(:businessRegistrationNumber)
    assert payload.key?(:businessRegistrationType)
    assert payload.key?(:businessRegistrationCountry)
    assert payload.key?(:entityType)
    assert payload.key?(:useCase)
    assert payload.key?(:messageVolume)
    assert payload.key?(:useCaseSummary)
    assert payload.key?(:productionMessageContent)
    assert payload.key?(:optInWorkflow)
    assert payload.key?(:optInWorkflowImageURLs)
    assert payload.key?(:additionalInformation)
    assert payload.key?(:isvReseller)
    assert payload.key?(:ageGatedContent)
    assert payload.key?(:phoneNumbers)

    # Ensure no snake_case keys
    refute payload.key?(:business_name)
    refute payload.key?(:corporate_website)
    refute payload.key?(:use_case)
  end

  test "isvReseller is always CoverText" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "CoverText", payload[:isvReseller]
  end

  test "useCase is always Insurance Services" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "Insurance Services", payload[:useCase]
  end

  test "ageGatedContent is always false" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal false, payload[:ageGatedContent]
  end

  test "phoneNumbers contains verification telnyx_number" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal [ { phoneNumber: "+18885551234" } ], payload[:phoneNumbers]
  end

  test "useCaseSummary includes business name" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_includes payload[:useCaseSummary], "Reliable Insurance Agency"
    assert_includes payload[:useCaseSummary], "customer-initiated"
    assert_includes payload[:useCaseSummary], "transactional"
  end

  test "productionMessageContent includes example messages with STOP" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert payload[:productionMessageContent].is_a?(Array)
    assert_operator payload[:productionMessageContent].length, :>=, 2

    payload[:productionMessageContent].each do |message|
      assert_includes message, "STOP"
    end
  end

  test "optInWorkflow includes business name and opt-out language" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_includes payload[:optInWorkflow], "Reliable Insurance Agency"
    assert_includes payload[:optInWorkflow], "STOP"
    assert_includes payload[:optInWorkflow], "HELP"
  end

  test "optInWorkflowImageURLs includes compliance opt-in flow URL" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal 1, payload[:optInWorkflowImageURLs].length
    assert_includes payload[:optInWorkflowImageURLs].first[:url], "compliance/opt-in-flow.png"
  end

  test "additionalInformation includes compliance language" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_includes payload[:additionalInformation], "Transactional use only"
    assert_includes payload[:additionalInformation], "Customer-initiated"
    assert_includes payload[:additionalInformation], "STOP"
  end

  test "defaults country to US when not provided" do
    @business_info.delete(:country)

    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "US", payload[:businessCountry]
    assert_equal "US", payload[:businessRegistrationCountry]
  end

  test "defaults businessRegistrationType to EIN when not provided" do
    @business_info.delete(:business_registration_type)

    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "EIN", payload[:businessRegistrationType]
  end

  test "defaults entityType to PRIVATE_PROFIT when not provided" do
    @business_info.delete(:entity_type)

    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "PRIVATE_PROFIT", payload[:entityType]
  end

  test "omits optional fields when not provided" do
    @business_info.delete(:address2)
    @business_info.delete(:business_registration_number)

    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    # Optional fields should be removed via .compact
    refute payload.key?(:businessAddress2)
    refute payload.key?(:businessRegistrationNumber)
  end

  test "messageVolume is 1,000" do
    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "1,000", payload[:messageVolume]
  end

  test "handles different business names correctly" do
    @business_info[:business_name] = "Acme Insurance Co"

    payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

    assert_equal "Acme Insurance Co", payload[:businessName]
    assert_includes payload[:useCaseSummary], "Acme Insurance Co"
    assert_includes payload[:optInWorkflow], "Acme Insurance Co"
  end

  test "supports all entity types" do
    entity_types = %w[SOLE_PROPRIETOR PRIVATE_PROFIT PUBLIC_PROFIT NON_PROFIT GOVERNMENT]

    entity_types.each do |entity_type|
      @business_info[:entity_type] = entity_type

      payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

      assert_equal entity_type, payload[:entityType]
    end
  end

  test "supports different business registration types" do
    registration_types = %w[EIN TAX_ID DUNS]

    registration_types.each do |reg_type|
      @business_info[:business_registration_type] = reg_type

      payload = Telnyx::TollFreeVerificationPayload.build(@verification, business_info: @business_info)

      assert_equal reg_type, payload[:businessRegistrationType]
    end
  end
end
