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

  require 'base64'

  # Setup output file
  out_dir = "../output"
  FileUtils.mkdir_p(out_dir) unless Dir.exist?(out_dir)
  
  timestamp = Time.now.to_f
  out_path = File.join(out_dir, "generated_#{timestamp}.png")
  
  # ImageMagick Command
  if shape == 'circle'
    # Circle with Border (Programmatic)
    border_color = "#89C997"
    border_width = 20
    
    cmd = "magick \"#{temp_file.path}\" -resize \"400x400^\" -gravity center -extent 400x400 " +
          "\\( +clone -alpha transparent -fill white -draw \"circle 200,200 200,0\" \\) -compose DstIn -composite " +
          "\\( +clone -alpha transparent -stroke \"#{border_color}\" -strokewidth #{border_width} -fill none -draw \"circle 200,200 200,#{border_width/2}\" \\) -compose Over -composite " +
          "\"#{out_path}\""
          
    system(cmd)
    
    unless $?.success?
      print "Content-type: text/plain\n"
      print "Status: 500 Internal Server Error\n\n"
      print "Error: Failed to execute ImageMagick (Circle)."
      exit
    end

  else
    # Square with Border (Programmatic)
    cmd = "magick \"#{temp_file.path}\" -resize \"800x800>\" -bordercolor \"#89C997\" -border 20 \"#{out_path}\""
    system(cmd)
    
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
