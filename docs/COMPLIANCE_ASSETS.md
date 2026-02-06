# Compliance Opt-In Flow Asset

## Overview
CoverText provides a publicly accessible opt-in workflow diagram at `/compliance/opt-in-flow.png` for carrier compliance verification (e.g., Telnyx Toll-Free number registration).

## Implementation Details

### Route
- **URL:** `GET /compliance/opt-in-flow.png`
- **Controller:** `Compliance::OptInFlowController#show`
- **Authentication:** None required (public access)
- **Caching:** Yes (served with inline disposition)

### Files
1. **Source:** `/public/compliance/opt-in-flow.svg` (4.1KB)
   - Hand-crafted SVG showing the opt-in workflow
   - Editable as plain text (XML format)
   
2. **Compiled:** `/public/compliance/opt-in-flow.png` (generated)
   - PNG version for systems requiring raster format
   - Generated via `bin/rails compliance:generate_opt_in_flow_png`
   - Requires ImageMagick on the server

3. **Controller:** `/app/controllers/compliance/opt_in_flow_controller.rb`
   - Serves PNG if available, falls back to SVG
   - Bypasses authentication (inherits from ActionController::Base)
   - Sets appropriate content-type headers

### Why This Approach?

**Static file in `/public` + controller fallback chosen because:**
- ✅ No authentication bypass needed (controller doesn't inherit ApplicationController)
- ✅ Files in `/public` are highly cacheable
- ✅ SVG works immediately; PNG can be generated later
- ✅ No external dependencies or build tools required
- ✅ Simple to update (edit SVG, regenerate PNG)
- ✅ Controller provides 404 handling and proper headers

**Alternatives considered:**
- ❌ Pure static file: No 404 handling, can't fallback SVG→PNG
- ❌ Asset pipeline: Adds unnecessary complexity, breaks in production
- ❌ Dynamic generation: Requires image libraries, slower, not cacheable
- ❌ External hosting: Adds dependency, can't version with code

## Content
The diagram shows:
1. **Customer initiates:** Client texts the agency toll-free number
2. **System confirms:** Automated reply with opt-in language and STOP/HELP
3. **Service messages:** Requested documents/info delivered via SMS
4. **Opt-out controls:** Clear STOP and HELP commands shown prominently

## Usage

### For Carrier Verification
When submitting a Telnyx Toll-Free verification:
1. Use the public URL: `https://yourdomain.com/compliance/opt-in-flow.png`
2. Carriers can access this without authentication
3. Image demonstrates compliant opt-in workflow

### Generating PNG
If the PNG file doesn't exist or needs regeneration:

```bash
# Requires ImageMagick installed on server
bin/rails compliance:generate_opt_in_flow_png
```

**Development environments without ImageMagick:**
- Use online converter: https://cloudconvert.com/svg-to-png
- Upload `public/compliance/opt-in-flow.svg`
- Download and save as `public/compliance/opt-in-flow.png`

### Updating the Diagram
1. Edit `/public/compliance/opt-in-flow.svg` directly (it's XML)
2. Regenerate PNG: `bin/rails compliance:generate_opt_in_flow_png`
3. Commit both files to version control

## Testing
```bash
bin/rails test test/controllers/compliance/opt_in_flow_controller_test.rb
```

Tests verify:
- Public access (no authentication)
- Proper content-type headers
- 404 handling when file missing
- Inline disposition for browser display

## Production Deployment
1. Ensure ImageMagick is installed on production servers
2. Run `bin/rails compliance:generate_opt_in_flow_png` as part of deployment
3. Or commit pre-generated PNG to repo (simpler)

## Maintenance
- **Update frequency:** Only when compliance requirements change
- **Version control:** Both SVG and PNG should be committed
- **Monitoring:** Verify URL accessibility in uptime checks
