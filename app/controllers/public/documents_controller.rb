module Public
  class DocumentsController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_authentication

    def show
      blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
      redirect_to rails_blob_url(blob, disposition: "inline"), allow_other_host: true
    rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
      head :not_found
    end
  end
end
