# Environment Variables Reference

## Required for Production/Staging

### Application Configuration
- `RAILS_ENV` - Rails environment (set to "production" for staging/prod)
- `APP_HOST` - Domain for the application (e.g., "staging.covertext.app")
- `APP_PROTOCOL` - Protocol for URL generation (e.g., "https")
- `RAILS_MASTER_KEY` - Key to decrypt credentials.yml.enc

### Database
- `DATABASE_URL` - PostgreSQL connection string
  - Format: `postgres://username:password@host:port/database`
  - Example: `postgres://postgres:password@covertext-postgres:5432/covertext_production`

### Twilio (Phase 1+)
**Primary Method: Rails Encrypted Credentials**

Twilio credentials MUST be configured in Rails encrypted credentials:

```bash
# For production
bin/rails credentials:edit --environment production

# For staging
bin/rails credentials:edit --environment staging
```

Add:
```yaml
twilio:
  account_sid: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  auth_token: your_auth_token_here
```

**Fallback: Environment Variables (Not Recommended)**
- `TWILIO_ACCOUNT_SID` - Twilio Account SID (fallback only)
- `TWILIO_AUTH_TOKEN` - Twilio Auth Token (fallback only)

⚠️ **Note:** The application checks Rails credentials first, then falls back to ENV vars. Using credentials is strongly recommended for security.

### Background Jobs
- `SOLID_QUEUE_IN_PUMA` - Set to "true" to run jobs in Puma process (default for single server)
- `JOB_CONCURRENCY` - Number of job worker threads (default: 1)

### Web Server
- `WEB_CONCURRENCY` - Number of Puma workers (default: matches CPU cores)
- `RAILS_MAX_THREADS` - Max threads per Puma worker (default: 5)

## Optional

### Logging
- `RAILS_LOG_LEVEL` - Log level (debug, info, warn, error, fatal)
- `RAILS_LOG_TO_STDOUT` - Set to "true" to log to stdout (recommended for Docker)

### Performance
- `BOOTSNAP_CACHE_DIR` - Bootsnap cache location (default: /tmp)

## Development Only

- `PORT` - Local development server port (default: 3000)

## Configuration Sources

1. **Secrets** (from `.kamal/secrets`):
   - RAILS_MASTER_KEY
   - POSTGRES_PASSWORD (for Postgres accessory)
   - KAMAL_REGISTRY_PASSWORD (for GHCR login)

2. **Clear env vars** (from `config/deploy.yml`):
   - RAILS_ENV
   - APP_HOST
   - APP_PROTOCOL
   - DATABASE_URL
   - SOLID_QUEUE_IN_PUMA

3. **Credentials** (encrypted in `config/credentials.yml.enc`):
   - Additional secrets can be stored here
   - Decrypted using RAILS_MASTER_KEY

## Verification

To verify environment in production:

```bash
# Check environment variables (without secrets)
kamal app exec "env | sort | grep -E 'RAILS_ENV|APP_HOST|DATABASE_URL'"

# Test database connection
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.active?'"

# Test Twilio credentials (checks credentials first, then ENV)
kamal app exec "bin/rails runner 'auth_token = Rails.application.credentials.dig(:twilio, :auth_token) || ENV[\"TWILIO_AUTH_TOKEN\"]; puts auth_token.present? ? \"Twilio credentials configured\" : \"Twilio credentials MISSING\"'"
```
