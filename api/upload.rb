require 'webrick'
require 'tempfile'
require 'base64'
require 'fileutils'

# Vercel Ruby Handler
Handler = Proc.new do |req, res|
  if req.request_method == 'GET'
    res.status = 405
    res.body = "Method Not Allowed"
    next
  end

  # WEBrick parses multipart form data automatically into req.query
  file_data = req.query['icon_image']
  
  unless file_data
    res.status = 400
    res.body = "No file uploaded"
    next
  end

  # file_data can be a String or WEBrick::HTTPUtils::FormData
  content = file_data.to_s
  
  # Write input to /tmp (Vercel's writable directory)
  # Use random filename to avoid collisions
  timestamp = Time.now.to_f
  in_path = "/tmp/input_#{timestamp}.png"
  File.binwrite(in_path, content)
  
  # Resolve frame path
  # Try to locate frames/default.png relative to the current working directory
  # On Vercel, CWD is usually the project root
  possible_paths = [
    File.join(Dir.pwd, 'frames', 'default.png'),
    File.join(Dir.pwd, '..', 'frames', 'default.png'),
    File.join(Dir.pwd, 'mirai_frame.png')
  ]
  
  frame_path = possible_paths.find { |p| File.exist?(p) }
  
  unless frame_path
    res.status = 500
    res.body = "Frame image not found. CWD: #{Dir.pwd}"
    next
  end

  out_path = "/tmp/output_#{timestamp}.png"
  out_path_circle = "/tmp/output_circle_#{timestamp}.png"

  # ImageMagick commands
  # Note: ImageMagick must be available in the Vercel environment (e.g. via buildpack or docker image)
  
  # 1. Square composite
  cmd = "magick \"#{in_path}\" -resize \"400x400^\" -gravity center -extent 400x400 \"#{frame_path}\" -gravity center -composite \"#{out_path}\""
  system(cmd)
  
  unless File.exist?(out_path)
    res.status = 500
    res.body = "ImageMagick processing failed (Square). Command: #{cmd}"
    next
  end

  # 2. Circle crop
  cmd_circle = "magick \"#{out_path}\" ( +clone -alpha transparent -fill white -draw \"circle 200,200 200,0\" ) -compose DstIn -composite \"#{out_path_circle}\""
  system(cmd_circle)

  unless File.exist?(out_path_circle)
    res.status = 500
    res.body = "ImageMagick processing failed (Circle)."
    next
  end

  # Read outputs and Base64 encode for Data URI
  b64_square = Base64.strict_encode64(File.binread(out_path))
  b64_circle = Base64.strict_encode64(File.binread(out_path_circle))
  
  data_uri_square = "data:image/png;base64,#{b64_square}"
  data_uri_circle = "data:image/png;base64,#{b64_circle}"
  
  # Clean up temp files
  File.delete(in_path) rescue nil
  File.delete(out_path) rescue nil
  File.delete(out_path_circle) rescue nil
  
  # Return HTML fragment
  res.status = 200
  res['Content-Type'] = 'text/html; charset=utf-8'
  res.body = <<HTML
<div class="success-container">
    <h3>完成しました！ (Vercel Ruby)</h3>
    
    <div class="result-grid">
        <div class="result-item">
            <div class="result-label">スクエア (Twitter/X推奨)</div>
            <img src="#{data_uri_square}" alt="Square Icon" style="border-radius: 8px;">
            <a href="#{data_uri_square}" download="mirai_icon_square.png" class="btn btn-primary" style="padding: 0.5rem 1rem; font-size: 0.9rem;">保存 (四角)</a>
        </div>
        
        <div class="result-item">
            <div class="result-label">サークル (丸形透過)</div>
            <img src="#{data_uri_circle}" alt="Circle Icon" style="border-radius: 50%;">
            <a href="#{data_uri_circle}" download="mirai_icon_circle.png" class="btn btn-primary" style="padding: 0.5rem 1rem; font-size: 0.9rem;">保存 (丸)</a>
        </div>
    </div>
    
    <div class="actions" style="margin-top: 2rem;">
        <button onclick="document.querySelector('form').reset(); document.getElementById('result').innerHTML='';" class="btn btn-secondary">リセット</button>
    </div>
</div>
HTML
end
