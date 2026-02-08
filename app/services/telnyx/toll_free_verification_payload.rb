module Telnyx
  class TollFreeVerificationPayload
    class << self
      def build(verification, business_info:)
        business_name = business_info[:business_name]

        {
          # Business identity (from agency)
          businessName: business_name,
          corporateWebsite: business_info[:corporate_website],
          businessContactFirstName: business_info[:contact_first_name],
          businessContactLastName: business_info[:contact_last_name],
          businessContactEmail: business_info[:contact_email],
          businessContactPhone: business_info[:contact_phone],
          businessAddr1: business_info[:address1],
          businessAddr2: business_info[:address2],
          businessCity: business_info[:city],
          businessState: business_info[:state],
          businessZip: business_info[:zip],

          # Optional business registration (EIN, etc.)
          businessRegistrationNumber: business_info[:business_registration_number],
          businessRegistrationType: business_info[:business_registration_type] || "EIN",
          businessRegistrationCountry: business_info[:country] || "US",

          # Entity type
          entityType: business_info[:entity_type] || "PRIVATE_PROFIT",

          # CoverText-generated use case information
          useCase: "Insurance Services",
          messageVolume: "1,000",
          useCaseSummary: use_case_summary(business_name),
          productionMessageContent: production_message_examples,

          # Opt-in workflow
          optInWorkflow: opt_in_workflow_description(business_name),
          optInWorkflowImageURLs: [ { url: opt_in_flow_url } ],

          # Additional compliance info
          additionalInformation: additional_information,
          isvReseller: "CoverText",
          ageGatedContent: false,

          # Phone number being verified
          phoneNumbers: [ { phoneNumber: verification.telnyx_number } ]
        }.compact # Remove nil values (like optional address2 or EIN)
      end

      private

      def use_case_summary(business_name)
        "Clients of #{business_name} text their agency's toll-free number to request proof of insurance, ID cards, policy information, and expiration reminders. All messaging is customer-initiated and transactional."
      end

      def production_message_examples
        [
          "Here is your auto insurance ID card for policy #ABC123. Reply STOP to opt out.",
          "Your policy expires on 03/15/2026. Contact your agent to renew. Reply STOP to opt out.",
          "Your insurance ID card has been updated. Download it here: [link]. Reply STOP to opt out."
        ]
      end

      def opt_in_workflow_description(business_name)
        "Clients opt in by initiating a text message to the agency's toll-free number. No marketing messages are sent. The first response includes: 'You are now connected with #{business_name} for insurance support. Reply STOP to opt out. Reply HELP for help. Msg & data rates may apply.'"
      end

      def opt_in_flow_url
        # In production: https://covertext.app/compliance/opt-in-flow.png
        # In development: http://localhost:3000/compliance/opt-in-flow.png
        if Rails.env.production?
          "https://covertext.app/compliance/opt-in-flow.png"
        else
          "http://localhost:3000/compliance/opt-in-flow.png"
        end
      end

      def additional_information
        "Transactional use only. Customer-initiated. Reply STOP to opt out at any time. Reply HELP for assistance. No marketing or promotional messages."
      end
    end
  end
end
