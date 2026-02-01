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
  - **Tool**: ChunkyPNG
  - **Process**:
    1. Receives image via POST.
    2. Resizes and applies border using **ChunkyPNG** (Pure Ruby, no ImageMagick dependency).
       - **Square**: Resizes to max 800x800, adds 20px border.
       - **Circle**: Resizes/Crops to 400x400, applies circular mask, draws 20px border.
    3. Encodes result to Base64.
    4. Returns HTML fragment with Data URI image and download link.

## Files
- `index.html`: Frontend UI.
- `api/upload.rb`: Vercel Serverless Entrypoint.
- `cgi-bin/ruby.cgi`: Local development/fallback CGI script.
