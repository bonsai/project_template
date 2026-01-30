# Tech Stack

## Frontend (FE)
- **Framework**: jQuery (AJAX)
- **Logic**:
  - User selects an image and a shape (Square/Circle).
  - Sends `multipart/form-data` to Backend.
  - Updates `#result` div with returned HTML fragment.
- **UI**:
  - Simple HTML5 form.
  - No page reload (Single Page interaction).
  - Team Mirai Official Color: `#89C997`.

## Backend (BE)
- **Environment**: Vercel Serverless Function (Ruby)
- **Language**: Ruby
- **Libraries**:
  - `webrick` (for Vercel/Local request handling)
  - `fileutils`, `tempfile` (Standard Libs)
- **Image Processing**:
  - **Tool**: ImageMagick (`magick` CLI)
  - **Process**:
    1. Resize uploaded image to 400x400 (Centered/Cover).
    2. Composite with Frame (`frames/default.png` or `mirai_frame.png`).
    3. (Optional) Mask to Circle if requested.
    4. Encodes result to Base64.
  - **Output**: Returns HTML fragment with Data URI image and download link.

## Files
- `index.html`: Frontend UI.
- `api/upload.rb`: Vercel Serverless Entrypoint.
- `cgi-bin/ruby.cgi`: Local development/fallback CGI script.
