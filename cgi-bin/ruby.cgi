#!ruby
# encoding: utf-8

require 'cgi'
require 'fileutils'
require 'tempfile'

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

  # Save to temp file
  temp_file = Tempfile.new(['upload', '.png'])
  temp_file.binmode
  temp_file.write(icon_image.read)
  temp_file.close

  # Resolve frame image path
  # Try relative paths from cgi-bin
  frame_image = "../frames/default.png"
  
  if File.exist?("../frames/mirai_frame.png")
    frame_image = "../frames/mirai_frame.png"
  elsif File.exist?("../mirai_frame.png")
    frame_image = "../mirai_frame.png"
  elsif File.exist?("mirai_frame.png")
    frame_image = "mirai_frame.png"
  end

  unless File.exist?(frame_image) && File.size(frame_image) > 0
    # Fallback search
    possible = ["../frames/default.png", "frames/default.png", "../frames/mirai_frame.png"]
    found = possible.find { |p| File.exist?(p) }
    if found
      frame_image = found
    else
      print "Content-type: text/plain\n"
      print "Status: 500 Internal Server Error\n\n"
      print "Error: Frame image not found."
      exit
    end
  end

  # Setup output file
  out_dir = "../output"
  FileUtils.mkdir_p(out_dir) unless Dir.exist?(out_dir)
  
  timestamp = Time.now.to_f
  out_path = File.join(out_dir, "generated_#{timestamp}.png")
  
  # ImageMagick Command
  if shape == 'circle'
    # 1. Base Composite (Square fixed for Circle)
    cmd = "magick \"#{temp_file.path}\" -resize \"400x400^\" -gravity center -extent 400x400 \"#{frame_image}\" -gravity center -composite \"#{out_path}\""
    system(cmd)
    
    unless $?.success?
      print "Content-type: text/plain\n"
      print "Status: 500 Internal Server Error\n\n"
      print "Error: Failed to execute ImageMagick (Circle Base)."
      exit
    end

    # 2. Crop circle
    tmp_circle = out_path + ".circle.png"
    cmd_circle = "magick \"#{out_path}\" ( +clone -alpha transparent -fill white -draw \"circle 200,200 200,0\" ) -compose DstIn -composite \"#{tmp_circle}\""
    system(cmd_circle)
    
    if $?.success?
      FileUtils.mv(tmp_circle, out_path)
    end
  else
    # Square / Original Shape
    # Keep original aspect ratio, resize if too large, add simple colored border
    cmd = "magick \"#{temp_file.path}\" -resize \"800x800>\" -bordercolor \"#89C997\" -border 20 \"#{out_path}\""
    system(cmd)
    
require 'base64'

    unless $?.success?
      print "Content-type: text/plain\n"
      print "Status: 500 Internal Server Error\n\n"
      print "Error: Failed to execute ImageMagick (Border)."
      exit
    end
  end
  
  # Return HTML with Base64 Image
  b64_data = Base64.strict_encode64(File.binread(out_path))
  data_uri = "data:image/png;base64,#{b64_data}"
  
  dl_filename = shape == 'circle' ? 'mirai_icon_circle.png' : 'mirai_image_framed.png'
  
  print "Content-type: text/html; charset=utf-8\n\n"
  
  print <<HTML
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
  print "Content-type: text/plain\n"
  print "Status: 500 Internal Server Error\n\n"
  print "Error: #{e.message}"
end
