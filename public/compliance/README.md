# Compliance Opt-In Flow Image

## Overview
This directory contains a static opt-in workflow diagram used for carrier compliance verification (e.g., Telnyx Toll-Free number verification).

## Files
- `opt-in-flow.svg` - Vector graphic showing the SMS opt-in workflow
- `opt-in-flow.png` - PNG version (generated from SVG)

## Access
The image is publicly accessible at:
- SVG: `https://yourdomain.com/compliance/opt-in-flow.svg`
- PNG: `https://yourdomain.com/compliance/opt-in-flow.png`

Files in `/public` are served directly by the web server without requiring Rails authentication or routing configuration.

## Generating PNG from SVG
If you need to regenerate the PNG (e.g., after updating the SVG):

### Option 1: Using Rails task (requires ImageMagick)
```bash
bin/rails compliance:generate_opt_in_flow_png
```

### Option 2: Using online converter
1. Open https://cloudconvert.com/svg-to-png
2. Upload `opt-in-flow.svg`
3. Convert and download
4. Save as `opt-in-flow.png` in this directory

### Option 3: Using local tools (if ImageMagick is installed)
```bash
convert public/compliance/opt-in-flow.svg public/compliance/opt-in-flow.png
```

## Carrier Compliance Requirements
This diagram demonstrates:
1. Customer-initiated contact (inbound SMS)
2. System confirmation of opt-in
3. Service message delivery
4. Clear STOP/HELP instructions
5. No marketing messages

## Updating the Diagram
Edit `opt-in-flow.svg` directly - it's a text-based XML file. After editing, regenerate the PNG using one of the methods above.
