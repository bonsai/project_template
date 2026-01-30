require 'webrick'
require 'tempfile'
require 'fileutils'

# Vercel Ruby Handler
Handler = Proc.new do |req, res|
  if req.request_method == 'GET'
    res.status = 405
    res.body = "Method Not Allowed"
    next
  end

  # Handle Multipart Form Data
  # Vercel's WEBrick wrapper should handle parsing automatically if Content-Type is correct
  # req.query contains params
  
  file_data = req.query['image'] || req.query['icon_image']
  shape = req.query['shape'] || 'square'
  
  unless file_data
    res.status = 400
    res.body = "No file uploaded"
    next
  end

  # file_data can be a String or WEBrick::HTTPUtils::FormData
  content = file_data.to_s
  
  # Write input to /tmp (Vercel's writable directory)
  timestamp = Time.now.to_f
  in_path = "/tmp/input_#{timestamp}.png"
  File.binwrite(in_path, content)
  
  # Resolve frame path
  possible_paths = [
    File.join(Dir.pwd, 'frames', 'mirai_frame.png'),
    File.join(Dir.pwd, '..', 'frames', 'mirai_frame.png'),
    File.join(Dir.pwd, 'mirai_frame.png'),
    File.join(Dir.pwd, 'frames', 'default.png')
  ]
  
  frame_path = possible_paths.find { |p| File.exist?(p) }
  
  unless frame_path
    res.status = 500
    res.body = "Frame image not found. CWD: #{Dir.pwd}"
    next
  end

  out_path = "/tmp/output_#{timestamp}.png"

  # ImageMagick commands
  if shape == 'circle'
    # 1. Base Composite (Square fixed for Circle)
    # Using existing frame logic for circle to maintain icon standard
    cmd = "magick \"#{in_path}\" -resize \"400x400^\" -gravity center -extent 400x400 \"#{frame_path}\" -gravity center -composite \"#{out_path}\""
    system(cmd)
    
    unless File.exist?(out_path)
      res.status = 500
      res.body = "ImageMagick processing failed. Command: #{cmd}"
      next
    end

    # 2. Crop circle
    tmp_circle = out_path + ".circle.png"
    cmd_circle = "magick \"#{out_path}\" ( +clone -alpha transparent -fill white -draw \"circle 200,200 200,0\" ) -compose DstIn -composite \"#{tmp_circle}\""
    system(cmd_circle)
    
    if File.exist?(tmp_circle)
      FileUtils.mv(tmp_circle, out_path)
    end
  else
    # Square / Original Shape
    # Keep original aspect ratio, resize if too large, add simple colored border
    # Color: #89C997 (Team Mirai Official Color)
    # Border width: 20px (fixed for simplicity, or could be relative)
    
    cmd = "magick \"#{in_path}\" -resize \"800x800>\" -bordercolor \"#89C997\" -border 20 \"#{out_path}\""
    system(cmd)
    
require 'base64'

    unless File.exist?(out_path)
      res.status = 500
      res.body = "ImageMagick processing failed. Command: #{cmd}"
      next
    end
  end

  # Return HTML with Base64 Image
  b64_data = Base64.strict_encode64(File.binread(out_path))
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
  
  # Clean up temp files
  File.delete(in_path) rescue nil
  File.delete(out_path) rescue nil
end
