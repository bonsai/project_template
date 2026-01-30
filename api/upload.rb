require 'webrick'
require 'tempfile'
require 'fileutils'
require 'base64'
require 'chunky_png'

# Vercel Ruby Handler
Handler = Proc.new do |req, res|
  if req.request_method == 'GET'
    res.status = 405
    res.body = "Method Not Allowed"
    next
  end

  # Handle Multipart Form Data
  file_data = req.query['image'] || req.query['icon_image']
  shape = req.query['shape'] || 'square'
  
  unless file_data
    res.status = 400
    res.body = "No file uploaded"
    next
  end

  # file_data can be a String or WEBrick::HTTPUtils::FormData
  content = file_data.to_s
  
  # Check file size (0.5MB limit)
  if content.bytesize > 0.5 * 1024 * 1024
    res.status = 413 # Payload Too Large
    res.body = "File size exceeds 0.5MB limit"
    next
  end

  begin
    # Load image using ChunkyPNG
    image = ChunkyPNG::Image.from_blob(content)
    
    # Border color: #89C997
    border_color = ChunkyPNG::Color.from_hex('#89C997')
    border_width = 20
    
    if shape == 'circle'
      # 1. Resize/Crop to square 400x400
      target_size = 400
      
      # Calculate dimensions to cover 400x400
      ratio = [target_size.to_f / image.width, target_size.to_f / image.height].max
      new_width = (image.width * ratio).round
      new_height = (image.height * ratio).round
      
      # Resize
      image.resample_bilinear!(new_width, new_height)
      
      # Center crop to 400x400
      x_offset = (new_width - target_size) / 2
      y_offset = (new_height - target_size) / 2
      image.crop!(x_offset, y_offset, target_size, target_size)
      
      # 2. Mask to Circle and draw border
      radius = target_size / 2
      center_x = radius
      center_y = radius
      radius_sq = radius**2
      inner_radius_sq = (radius - border_width)**2
      
      # Create new transparent image
      final_image = ChunkyPNG::Image.new(target_size, target_size, ChunkyPNG::Color::TRANSPARENT)
      
      # Pixel manipulation
      target_size.times do |y|
        target_size.times do |x|
          dx = x - center_x
          dy = y - center_y
          dist_sq = dx**2 + dy**2
          
          if dist_sq <= inner_radius_sq
            # Inside inner circle: copy original pixel
            final_image[x, y] = image[x, y]
          elsif dist_sq <= radius_sq
            # Inside border area: draw border color
            # Simple anti-aliasing logic could go here, but keeping it simple for now
            final_image[x, y] = border_color
          else
            # Outside circle: transparent (default)
          end
        end
      end
      
      out_blob = final_image.to_blob
      
    else
      # Square with Border
      # Resize to max 800x800 if larger, preserving aspect ratio
      max_size = 800
      if image.width > max_size || image.height > max_size
        ratio = [max_size.to_f / image.width, max_size.to_f / image.height].min
        new_width = (image.width * ratio).round
        new_height = (image.height * ratio).round
        image.resample_bilinear!(new_width, new_height)
      end
      
      # Add border
      # Create new image with border dimensions
      new_width = image.width + (border_width * 2)
      new_height = image.height + (border_width * 2)
      final_image = ChunkyPNG::Image.new(new_width, new_height, border_color)
      
      # Composite original image onto center
      final_image.compose!(image, border_width, border_width)
      
      out_blob = final_image.to_blob
    end

    # Return HTML with Base64 Image
    b64_data = Base64.strict_encode64(out_blob)
    data_uri = "data:image/png;base64,#{b64_data}"
    
    res.status = 200
    res['Content-Type'] = 'text/html; charset=utf-8'
    
    # Determine download filename
    dl_filename = shape == 'circle' ? 'mirai_icon_circle.png' : 'mirai_image_framed.png'
    
    res.body = <<HTML
<div class="result-container" style="text-align: center;">
    <div class="result-item">
        <img src="#{data_uri}" alt="Generated Image" style="max-width: 100%; border-radius: #{shape == 'circle' ? '50%' : '8px'}; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <div style="margin-top: 1rem;">
            <a href="#{data_uri}" download="#{dl_filename}" class="btn btn-primary" style="
                display: inline-block;
                padding: 10px 20px;
                background-color: #89C997;
                color: white;
                text-decoration: none;
                border-radius: 5px;
                font-weight: bold;
            ">保存する</a>
        </div>
    </div>
</div>
HTML

  rescue => e
    res.status = 500
    res.body = "Processing failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end
end
