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
  # Get uploaded file
  icon_image = cgi.params['icon_image'][0]

  unless icon_image
    print "Content-type: text/html\n\n"
    print "<h3>Error: No file uploaded.</h3>"
    exit
  end

  # Save to temp file
  # icon_image is a StringIO or Tempfile-like object
  temp_file = Tempfile.new(['upload', '.png'])
  temp_file.binmode
  temp_file.write(icon_image.read)
  temp_file.close

  # Resolve frame image path
  # Assuming running in cgi-bin/
  frame_image = "../frames/default.png"
  
  if File.exist?("../mirai_frame.png")
    frame_image = "../mirai_frame.png"
  elsif File.exist?("mirai_frame.png")
    frame_image = "mirai_frame.png"
  end
  
  # Fallback check
  unless File.exist?(frame_image)
    if File.exist?("../frames/default.png")
      frame_image = "../frames/default.png"
    elsif File.exist?("frames/default.png")
      frame_image = "frames/default.png"
    else
      print "Content-type: text/html\n\n"
      print "<h3>Error: Frame image not found.</h3>"
      exit
    end
  end

  # Setup output directory
  out_dir = "../output"
  FileUtils.mkdir_p(out_dir) unless Dir.exist?(out_dir)
  
  timestamp = Time.now.to_i
  out_filename = "generated_#{timestamp}.png"
  out_path = File.join(out_dir, out_filename)
  
  # ImageMagick Command (Square)
  # Resize user image to 400x400^, gravity center extent 400x400, then composite frame
  cmd = "magick \"#{temp_file.path}\" -resize \"400x400^\" -gravity center -extent 400x400 \"#{frame_image}\" -gravity center -composite \"#{out_path}\""
  
  system(cmd)
  
  unless $?.success?
    print "Content-type: text/html\n\n"
    print "<div class='error'>Error: Failed to execute ImageMagick.</div>"
    exit
  end
  
  # Create Circle Version
  out_filename_circle = "generated_#{timestamp}_circle.png"
  out_path_circle = File.join(out_dir, out_filename_circle)
  
  # Magick command to crop circle
  cmd_circle = "magick \"#{out_path}\" ( +clone -alpha transparent -fill white -draw \"circle 200,200 200,0\" ) -compose DstIn -composite \"#{out_path_circle}\""
  system(cmd_circle)
  
  # Return HTML fragment
  print "Content-type: text/html\n\n"
  print <<HTML
<div class="success-container">
    <h3>完成しました！ (Ruby Version)</h3>
    
    <div class="result-grid">
        <div class="result-item">
            <div class="result-label">スクエア (Twitter/X推奨)</div>
            <img src="/output/#{out_filename}" alt="Square Icon" style="border-radius: 8px;">
            <a href="/output/#{out_filename}" download="mirai_icon_square.png" class="btn btn-primary" style="padding: 0.5rem 1rem; font-size: 0.9rem;">保存 (四角)</a>
        </div>
        
        <div class="result-item">
            <div class="result-label">サークル (丸形透過)</div>
            <img src="/output/#{out_filename_circle}" alt="Circle Icon" style="border-radius: 50%;">
            <a href="/output/#{out_filename_circle}" download="mirai_icon_circle.png" class="btn btn-primary" style="padding: 0.5rem 1rem; font-size: 0.9rem;">保存 (丸)</a>
        </div>
    </div>
    
    <div class="actions" style="margin-top: 2rem;">
        <button onclick="document.querySelector('form').reset(); document.getElementById('result').innerHTML='';" class="btn btn-secondary">リセット</button>
    </div>
</div>
HTML

rescue => e
  print "Content-type: text/html\n\n"
  print "<h3>Error: #{e.message}</h3>"
  # print "<pre>#{e.backtrace.join("\n")}</pre>" # Uncomment for debugging
end
