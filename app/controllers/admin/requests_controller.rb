module Admin
  class RequestsController < BaseController
    def index
      @requests = current_agency.requests.order(created_at: :desc)

      # Optional filters
      @requests = @requests.where(request_type: params[:request_type]) if params[:request_type].present?
      @requests = @requests.where(status: params[:status]) if params[:status].present?

      @requests = @requests.page(params[:page]).per(25) if defined?(Kaminari)
    end

    def show
      @request = current_agency.requests.find_by(id: params[:id])
      return head :not_found unless @request

      @client = @request.client
      @deliveries = @request.deliveries.order(created_at: :desc)
      @audit_events = @request.audit_events.order(created_at: :desc)

      # Get transcript messages - related message logs
      @messages = fetch_transcript_messages
    end

    private

    def fetch_transcript_messages
      # Primary: Messages directly linked to this request
      direct_messages = MessageLog.where(
        agency_id: current_agency.id,
        request_id: @request.id
      )

      # Fallback: Messages from same phone within time window if no direct messages
      if direct_messages.empty? && @request.client
        time_window = 10.minutes
        phone = @request.client.phone_mobile

        fallback_messages = MessageLog.where(
          agency_id: current_agency.id
        ).where(
          "(from_phone = ? OR to_phone = ?) AND created_at BETWEEN ? AND ?",
          phone,
          phone,
          @request.created_at - time_window,
          @request.created_at + time_window
        )

        fallback_messages.order(created_at: :asc)
      else
        direct_messages.order(created_at: :asc)
      end
    end
  end
end
