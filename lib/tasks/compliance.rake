namespace :compliance do
  desc "Generate PNG opt-in flow diagram from SVG source"
  task generate_opt_in_flow_png: :environment do
    require "mini_magick"

    svg_path = Rails.root.join("public/compliance/opt-in-flow.svg")
    png_path = Rails.root.join("public/compliance/opt-in-flow.png")

    unless File.exist?(svg_path)
      puts "❌ SVG source not found at #{svg_path}"
      exit 1
    end

    begin
      # Convert SVG to PNG using ImageMagick via mini_magick
      image = MiniMagick::Image.open(svg_path)
      image.format "png"
      image.write png_path

      puts "✅ Generated PNG at #{png_path}"
      puts "   File size: #{File.size(png_path)} bytes"
      puts "   Accessible at: /compliance/opt-in-flow.png"
    rescue => e
      puts "❌ Error generating PNG: #{e.message}"
      puts "   Make sure ImageMagick is installed on the system"
      exit 1
    end
  end
end
