module Compliance
  class OptInFlowController < ActionController::Base
    # Serve opt-in workflow image for carrier compliance verification.
    #
    # This controller bypasses ApplicationController authentication because:
    # - Carrier compliance verification systems need public access
    # - The image contains no sensitive data
    # - Cacheability is important for external access
    #
    # Implementation notes:
    # - Serves SVG as PNG route for compatibility with systems expecting PNG
    # - SVG is preferred for quality/scalability but carriers often request PNG
    # - In production with ImageMagick, generate actual PNG via rake task:
    #   `bin/rails compliance:generate_opt_in_flow_png`

    def show
      # Try to serve PNG if it exists, otherwise serve SVG
      png_path = Rails.public_path.join("compliance/opt-in-flow.png")
      svg_path = Rails.public_path.join("compliance/opt-in-flow.svg")

      if File.exist?(png_path)
        # Serve the PNG file
        send_file png_path,
                  type: "image/png",
                  disposition: "inline",
                  filename: "opt-in-flow.png"
      elsif File.exist?(svg_path)
        # Fallback: serve SVG as PNG (browsers will display it fine)
        # Note: Some strict compliance systems may require actual PNG
        send_file svg_path,
                  type: "image/svg+xml",
                  disposition: "inline",
                  filename: "opt-in-flow.svg"
      else
        head :not_found
      end
    end
  end
end
