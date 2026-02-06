require "test_helper"

class Compliance::OptInFlowControllerTest < ActionDispatch::IntegrationTest
  test "should get opt-in flow image without authentication" do
    # This route must be publicly accessible for carrier compliance verification
    get compliance_opt_in_flow_path

    assert_response :success
    # Should serve SVG since PNG doesn't exist yet in test environment
    assert_equal "image/svg+xml", @response.content_type
  end

  test "should serve with inline disposition for browser display" do
    get compliance_opt_in_flow_path

    assert_response :success
    assert_match /inline/, @response.headers["Content-Disposition"]
  end

  test "should return 404 if file is missing" do
    # Temporarily rename the SVG file to test 404 behavior
    svg_path = Rails.public_path.join("compliance/opt-in-flow.svg")
    backup_path = Rails.public_path.join("compliance/opt-in-flow.svg.backup")

    FileUtils.mv(svg_path, backup_path) if File.exist?(svg_path)

    get compliance_opt_in_flow_path
    assert_response :not_found

    # Restore the file
    FileUtils.mv(backup_path, svg_path) if File.exist?(backup_path)
  end
end
