require "test_helper"

class Public::DocumentsControllerTest < ActionDispatch::IntegrationTest
  test "returns 200 for valid signed blob id" do
    # Create a document with an attachment
    policy = policies(:alice_honda)
    document = policy.documents.find_by(kind: "auto_id_card")

    # Ensure file is attached (seeds should do this, but be explicit)
    unless document.file.attached?
      document.file.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "sample_insurance_card.pdf")),
        filename: "insurance_card.pdf",
        content_type: "application/pdf"
      )
    end

    blob = document.file.blob

    get "/public/documents/#{blob.signed_id}"

    # Controller redirects to the actual blob URL
    assert_response :redirect
  end

  test "returns 404 for invalid signed id" do
    get "/public/documents/invalid_signed_id"
    assert_response :not_found
  end

  test "returns 404 for expired signed id" do
    # Create a signed ID that's already expired
    policy = policies(:alice_honda)
    document = policy.documents.find_by(kind: "auto_id_card")

    unless document.file.attached?
      document.file.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "sample_insurance_card.pdf")),
        filename: "insurance_card.pdf",
        content_type: "application/pdf"
      )
    end

    blob = document.file.blob
    expired_signed_id = blob.signed_id(expires_in: 1.minute)

    # Travel 2 minutes to expire it
    travel 2.minutes do
      get "/public/documents/#{expired_signed_id}"
      assert_response :not_found
    end
  end
end
