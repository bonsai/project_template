#!ruby
# encoding: utf-8

require 'cgi'
require 'fileutils'
require 'tempfile'
require 'base64'
require 'chunky_png'

# Initialize CGI
cgi = CGI.new

# Check request method
if cgi.request_method == 'GET'
  print "Content-type: text/html\n\n"
  print "<h3>405 Method Not Allowed</h3>"
  exit
end

# Handle POST request
begin
  # Get params
  # Note: jQuery form data keys: 'image', 'shape'
  icon_image = cgi.params['image'][0] || cgi.params['icon_image'][0]
  shape = cgi.params['shape'][0] || 'square'

  unless icon_image
    print "Content-type: text/plain\n"
    print "Status: 400 Bad Request\n\n"
    print "Error: No file uploaded."
    exit
  end

  # Check file size (5MB limit)
  # icon_image is a StringIO or Tempfile, depending on size. 
  # .size method works for both.
  if icon_image.size > 5 * 1024 * 1024
    print "Content-type: text/plain\n"
    print "Status: 413 Payload Too Large\n\n"
    print "Error: File size exceeds 5MB limit"
    exit
  end

  # Load image using ChunkyPNG
  image = ChunkyPNG::Image.from_blob(icon_image.read)
  
  # Border color: #89C997
  border_color = ChunkyPNG::Color.from_hex('#89C997')
  border_width = 20
  
  if shape == 'circle'
    target_size = 400
    scale = 2
    render_size = target_size * scale
    border_width_scaled = border_width * scale
    
    ratio = [render_size.to_f / image.width, render_size.to_f / image.height].max
    new_width = (image.width * ratio).round
    new_height = (image.height * ratio).round
    
    image.resample_bilinear!(new_width, new_height)
    
    x_offset = (new_width - render_size) / 2
    y_offset = (new_height - render_size) / 2
    image.crop!(x_offset, y_offset, render_size, render_size)
    
    radius = render_size / 2
    center_x = radius
    center_y = radius
    radius_sq = radius**2
    inner_radius_sq = (radius - border_width_scaled)**2
    
    final_image = ChunkyPNG::Image.new(render_size, render_size, ChunkyPNG::Color::TRANSPARENT)
    
    render_size.times do |y|
      render_size.times do |x|
        dx = x - center_x
        dy = y - center_y
        dist_sq = dx**2 + dy**2
        
        if dist_sq <= inner_radius_sq
          final_image[x, y] = image[x, y]
        elsif dist_sq <= radius_sq
          final_image[x, y] = border_color
        end
      end
    end
    
    final_image.resample_bilinear!(target_size, target_size)
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
  
  dl_filename = shape == 'circle' ? 'mirai_icon_circle.png' : 'mirai_image_framed.png'
  
  print "Content-type: text/html; charset=utf-8\n\n"
  
  print <<HTML
<div class="result-container" style="text-align: center; animation: fadeIn 0.5s ease;">
    <div class="result-item">
        <img src="#{data_uri}" alt="Generated Image" style="max-width: 100%; border-radius: #{shape == 'circle' ? '50%' : '22px'}; box-shadow: 0 8px 20px rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1);">
        <div style="margin-top: 24px;">
            <a href="#{data_uri}" download="#{dl_filename}" style="
                background-color: #34C759;
                color: #FFFFFF;
                border: none;
                border-radius: 999px;
                padding: 12px 32px;
                font-weight: 600;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                box-shadow: 0 4px 12px rgba(52, 199, 89, 0.4);
                text-decoration: none;
                display: inline-block;
                font-size: 16px;
                transition: opacity 0.2s;
            " onmouseover="this.style.opacity='0.9'" onmouseout="this.style.opacity='1'">保存する</a>
        </div>
    </div>
</div>
HTML

rescue => e
  print "Content-type: text/plain\n"
  print "Status: 500 Internal Server Error\n\n"
  print "Error: #{e.message}\n#{e.backtrace.join("\n")}"
end
