require "test_helper"

class ProcessInboundMessageJobTest < ActiveJob::TestCase
  test "performs without error" do
    message_log = MessageLog.create!(
      agency: agencies(:reliable),
      direction: "inbound",
      from_phone: "+15559876543",
      to_phone: agencies(:reliable).sms_phone_number,
      body: "Test message",
      provider_message_id: "SM#{SecureRandom.hex(16)}",
      media_count: 0
    )

    assert_nothing_raised do
      ProcessInboundMessageJob.perform_now(message_log.id)
    end
  end

  test "can be enqueued" do
    assert_enqueued_with(job: ProcessInboundMessageJob, args: [ 123 ]) do
      ProcessInboundMessageJob.perform_later(123)
    end
  end
end
