# Deployment Guide: CoverText Multi-Environment

This guide covers deploying CoverText to staging and production environments using Kamal and GitHub Container Registry (GHCR).

## Overview

CoverText uses Kamal **destinations** to support multiple deployment environments:

- **Staging** (`staging.covertext.app`)
  - Separate staging server
  - Postgres accessory on same droplet
  - Staging Twilio API key
  - Deploy with: `kamal deploy -d staging`

- **Production** (`covertext.app`)
  - Separate production server
  - Digital Ocean managed Postgres
  - Production Twilio API key
  - Deploy with: `kamal deploy -d production`

## Prerequisites

**For each environment (staging and production):**

- A Linux server (Ubuntu 22.04+ recommended) with:
  - Docker installed
  - SSH access via public key
  - Port 80 and 443 open to internet
  - **Staging:** At least 2GB RAM, 20GB disk
  - **Production:** At least 4GB RAM, 40GB disk (or more based on load)

- GitHub account with:
  - Write access to the covertext repository
  - Personal Access Token (PAT) with `write:packages` scope

- DNS configured:
  - `staging.covertext.app` → Staging server IP
  - `covertext.app` → Production server IP

- **Production only:** Digital Ocean managed Postgres cluster

## 1. Create GitHub Container Registry Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "Kamal GHCR Deploy - CoverText Staging"
4. Select scopes:
   - ✅ `write:packages` (includes read:packages)
   - ✅ `read:packages`
   - ✅ `delete:packages` (optional, for cleanup)
5. Click "Generate token"
6. **Copy the token immediately** - you won't see it again!

## 2. Configure Deployment

### Update config/deploy.yml

Replace placeholders with your actual values:

```yaml
# Line 5: Replace <GITHUB_OWNER>
image: ghcr.io/your-github-username/covertext

# Staging destination (around line 17-18)
destinations:
  staging:
    servers:
      web:
        hosts:
          - 123.45.67.89  # Your staging server IP
    # ... other staging config ...
    accessories:
      postgres:
        host: 123.45.67.89  # Same as staging server

# Production destination (around line 41-42)
  production:
    servers:
      web:
        hosts:
          - 234.56.78.90  # Your production server IP
```
accessories:
  postgres:
    host: 123.45.67.89
```

### Create .kamal/secrets file

Create the secrets file (NOT committed to git):

```bash
mkdir -p .kamal
cat > .kamal/secrets << 'EOF'
# GitHub Container Registry password (your PAT)
KAMAL_REGISTRY_PASSWORD=ghp_your_token_here

# Rails master key (from config/master.key)
RAILS_MASTER_KEY=$(cat config/master.key)

# Staging: Postgres password (generate a strong password)
POSTGRES_PASSWORD=your_strong_postgres_password_here

# Production: Digital Ocean Postgres connection string
# Get from Digital Ocean database cluster settings
# DATABASE_URL=postgres://doadmin:password@your-db-cluster.db.ondigitalocean.com:25060/covertext_production?sslmode=require
EOF

chmod 600 .kamal/secrets
```

**Important**: `.kamal/secrets` is in `.gitignore` - never commit it!

### Configure Twilio Credentials

**Recommended: Use Rails Encrypted Credentials with API Keys**

Create separate API Keys in Twilio Console for each environment:
1. Go to: https://console.twilio.com/us1/account/keys-credentials/api-keys
2. Create "CoverText Staging" API Key (mark as "test")
3. Create "CoverText Production" API Key (mark as "production")

**Staging:**
```bash
bin/rails credentials:edit --environment staging
```

Add:
```yaml
twilio:
  account_sid: SKxxxxxxxx_staging_api_key_sid
  auth_token: your_staging_api_key_secret
```

**Production:**
```bash
bin/rails credentials:edit --environment production
```

Add:
```yaml
twilio:
  account_sid: SKxxxxxxxx_production_api_key_sid
  auth_token: your_production_api_key_secret
```

Save and exit. The encrypted files are committed to git, but you need to securely share `config/credentials/staging.key` and `config/credentials/production.key` with your team.

**Alternative: Use Environment Variables**

If you prefer ENV vars, add to `.kamal/secrets`:
```bash
TWILIO_ACCOUNT_SID=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token_or_api_key_secret
```

The initializer checks Rails credentials first, then falls back to ENV vars.

## 3. Initial Setup

### Registry Login

Login to GitHub Container Registry:

```bash
kamal registry login
```

This will prompt for your GHCR password (use the PAT you created).

### Staging Setup

Initialize Kamal on staging server (installs Docker, sets up network, starts Postgres):

```bash
kamal setup -d staging
```

This will:
- Install Docker on the server (if needed)
- Create Docker network
- Start Postgres accessory (covertext-postgres-staging)
- Pull the image
- Deploy the application
- Start the Kamal proxy (Traefik) with SSL

Wait 10-20 seconds for Postgres to initialize.

Run database migrations:

```bash
kamal app exec -d staging 'bin/rails db:prepare'
```

Seed the database:

```bash
kamal app exec -d staging 'bin/rails db:seed'
```

### Production Setup

Initialize Kamal on production server:

```bash
kamal setup -d production
```

This will:
- Install Docker on the server (if needed)
- Create Docker network
- Pull the image
- Deploy the application
- Start the Kamal proxy (Traefik) with SSL

Run database migrations:

```bash
kamal app exec -d production 'bin/rails db:prepare'
```

Seed the database (if needed):

```bash
```bash
kamal app exec -d production 'bin/rails db:seed'
```

**Note:** Production uses Digital Ocean managed Postgres - no accessory to manage.

## 4. Deploy Application

### Deploy to Staging

```bash
kamal deploy -d staging
```

This will:
- Build Docker image
- Push to GHCR
- Deploy to staging server
- Restart application

### Deploy to Production

```bash
kamal deploy -d production
```

This will:
- Build Docker image
- Push to GHCR
- Deploy to production server
- Restart application

### Individual Build Steps

```bash
# Build and push image
kamal build push -d staging

# Deploy without rebuilding
kamal deploy -d staging --skip-push
```

## 5. Verify Deployment

### Check Staging Application Status

```bash
# View running containers
kamal app details -d staging

# Tail application logs
kamal app logs -f -d staging

# Check Postgres accessory
kamal accessory details postgres -d staging
```

### Check Production Application Status

```bash
# View running containers
kamal app details -d production

# Tail application logs
kamal app logs -f -d production

# No Postgres accessory in production (using Digital Ocean managed)
```

### Access the Applications

**Staging:** https://staging.covertext.app

**Production:** https://covertext.app

Login with seed credentials:
- Email: john@reliableinsurance.example
- Password: password123

### Test Health Check

```bash
curl https://staging.covertext.app/up
curl https://covertext.app/up
```

Should return: `200 OK`

## 6. Configure Twilio Webhooks

### Staging Webhooks

Update your Twilio **test** phone number webhooks to point to staging:

**Messaging:**
- When a message comes in: `https://staging.covertext.app/twilio/incoming`
- HTTP POST

**Status Callbacks:**
- Status Callback URL: `https://staging.covertext.app/twilio/status`
- HTTP POST

### Production Webhooks

Update your Twilio **production** phone number webhooks:

**Messaging:**
- When a message comes in: `https://covertext.app/twilio/incoming`
- HTTP POST

**Status Callbacks:**
- Status Callback URL: `https://covertext.app/twilio/status`
- HTTP POST

## 7. Common Operations

### Deploying Updates

**To Staging:**
```bash
git push origin main
kamal deploy -d staging
```

**To Production:**
```bash
git push origin main
kamal deploy -d production
```

### Running Rails Commands

**Staging:**
```bash
# Rails console
kamal app exec -d staging -i 'bin/rails console'

# Database migrations
kamal app exec -d staging 'bin/rails db:migrate'

# Run a rake task
kamal app exec -d staging 'bin/rails db:seed'
```

**Production:**
```bash
# Rails console
kamal app exec -d production -i 'bin/rails console'

# Database migrations
kamal app exec -d production 'bin/rails db:migrate'
```

### Viewing Logs

**Staging:**
```bash
# Application logs
kamal app logs -f -d staging

# Last 100 lines
kamal app logs -n 100 -d staging

# Postgres logs
kamal accessory logs postgres -f -d staging
```

**Production:**
```bash
# Application logs
kamal app logs -f -d production

# Last 100 lines
kamal app logs -n 100 -d production
```

### Restarting Services

**Staging:**
```bash
# Restart application
kamal app boot -d staging

# Restart Postgres
kamal accessory reboot postgres -d staging

# Restart proxy
kamal proxy reboot -d staging
```

**Production:**
```bash
# Restart application
kamal app boot -d production

# Restart proxy
kamal proxy reboot -d production
```

### Rolling Back

**Staging:**
```bash
# Rollback to previous version
kamal rollback -d staging "1.0.0"
```

**Production:**
```bash
# Rollback to previous version
kamal rollback -d production "1.0.0"
```

## 8. Troubleshooting

### Staging-Specific Issues

**Postgres Connection Issues:**
```bash
# Check if Postgres is running
kamal accessory details postgres -d staging

# Restart Postgres
kamal accessory reboot postgres -d staging

# Check Postgres logs
kamal accessory logs postgres -d staging
```

**Database Not Found:**
```bash
# Recreate database
kamal app exec -d staging 'bin/rails db:drop db:create db:migrate'
```

### Production-Specific Issues

**Database Connection Issues:**
- Verify DATABASE_URL in `.kamal/secrets`
- Check Digital Ocean database firewall rules (allow production server IP)
- Verify SSL mode is set to `require` in connection string
- Test connection from server:
```bash
kamal app exec -d production 'bin/rails runner "puts ActiveRecord::Base.connection.execute(\"SELECT 1\").to_a"'
```

### General Issues

**Application Won't Start:**
```bash
# Check logs for errors
kamal app logs -d staging  # or -d production

# Check container status
kamal app details -d staging  # or -d production

# Restart application
kamal app boot -d staging  # or -d production

```

**SSL Certificate Issues:**
```bash
# Check proxy status
kamal proxy details -d staging  # or -d production

# Restart proxy to regenerate cert
kamal proxy reboot -d staging  # or -d production

# Check Traefik logs
kamal proxy logs -d staging  # or -d production
```

**Image Build Failures:**
```bash
# Check Docker build output
kamal build push -d staging --verbose

# Clear builder cache
docker builder prune -a
```

**Twilio Webhook Failures:**
```bash
# Check application logs for webhook errors
kamal app logs -d staging | grep twilio

# Verify webhook signature validation
kamal app exec -d staging -i 'bin/rails console'
# Then: Rails.application.credentials.twilio
```

## 9. Digital Ocean Postgres Setup (Production Only)

### Create Database Cluster

1. Log in to Digital Ocean
2. Navigate to Databases → Create Database
3. Choose:
   - Database: PostgreSQL (version 14 or higher)
   - Plan: Based on your needs (start with Basic 1GB)
   - Data center: Same region as your production server
   - Database name: `covertext-production`

4. Configure:
   - Add production server IP to trusted sources (firewall)
   - Enable SSL/TLS (required)

### Get Connection String

1. In database cluster settings, click "Connection Details"
2. Connection mode: "Connection String"
3. Copy the connection string (format: `postgresql://user:pass@host:port/db?sslmode=require`)
4. Add to `.kamal/secrets` as `DATABASE_URL`

Example:
```bash
DATABASE_URL=postgres://doadmin:xxxxxxxxx@covertext-production-do-user-123456-0.b.db.ondigitalocean.com:25060/covertext_production?sslmode=require
```

### Verify Connection

After deploying, verify the connection:
```bash
kamal app exec -d production 'bin/rails db:migrate:status'
```

## 10. Security Checklist

- [ ] `.kamal/secrets` is in `.gitignore` and NOT committed
- [ ] `config/credentials/staging.key` is securely shared (1Password, etc.)
- [ ] `config/credentials/production.key` is securely shared separately
- [ ] GitHub PAT has minimal permissions (read:packages, write:packages)
- [ ] Twilio uses separate API keys for staging and production
- [ ] Digital Ocean database has firewall rules limiting access to production server only
- [ ] DATABASE_URL uses `sslmode=require`
- [ ] Server SSH keys are secured and backed up
- [ ] DNS records are protected (registrar 2FA enabled)

## 11. Maintenance

### Updating Dependencies

**Both Environments:**
```bash
bundle update
git commit -am "Update gems"

# Deploy to staging first
kamal deploy -d staging

# After testing, deploy to production
kamal deploy -d production
```

### Database Backups

**Staging:**
```bash
# Manual backup
kamal accessory exec postgres -d staging "pg_dump -U postgres covertext_staging" > backup_staging.sql

# Restore
cat backup_staging.sql | kamal accessory exec postgres -d staging "psql -U postgres covertext_staging"
```

**Production:**

Set up automated backups in Digital Ocean:
1. Navigate to your database cluster
2. Enable "Automated Backups"
3. Choose retention period (7 days recommended minimum)

Manual backup:
```bash
# Using pg_dump from local machine
pg_dump "postgres://doadmin:password@host:25060/covertext_production?sslmode=require" > backup_production.sql
```

### Secrets Management

```bash
# Update environment variables
kamal env push -d staging  # or -d production

# View current environment (without secrets)
kamal app exec -d staging "env | sort"
```

### Updating Rails Credentials

**Staging:**
```bash
bin/rails credentials:edit --environment staging
# Make changes, save, commit encrypted file
git commit -am "Update staging credentials"
kamal deploy -d staging
```

**Production:**
```bash
bin/rails credentials:edit --environment production
# Make changes, save, commit encrypted file
git commit -am "Update production credentials"
kamal deploy -d production
```

## 12. SSL/TLS with Let's Encrypt

Kamal proxy (Traefik) automatically handles:
- SSL certificate provisioning via Let's Encrypt
- Certificate renewal (every 60 days)
- HTTP → HTTPS redirect
- HTTP/2 support

**Certificate storage**: `/root/.kamal/proxy/letsencrypt/` on each server

**Important**: Ensure DNS is configured BEFORE first deploy, or Let's Encrypt will fail.

## 13. Monitoring and Logs

### Log Aggregation

Consider using a log aggregation service for production:
- Papertrail
- Logtail
- Datadog
- New Relic

Add to credentials:
```yaml
# config/credentials/production.yml.enc
logtail:
  source_token: your_token_here
```

### Performance Monitoring

Recommended for production:
- New Relic APM
- Scout APM
- Skylight

### Uptime Monitoring

Set up external monitors:
- UptimeRobot
- Pingdom
- StatusCake

Monitor:
- `https://staging.covertext.app/up`
- `https://covertext.app/up`

## 14. Disaster Recovery

### Staging Recovery

If staging needs complete rebuild:
```bash
# Destroy everything
kamal accessory remove postgres -d staging
kamal app remove -d staging
kamal proxy remove -d staging

# Rebuild from scratch
kamal setup -d staging
kamal app exec -d staging 'bin/rails db:prepare db:seed'
```

### Production Recovery

**Database:** Use Digital Ocean automated backups to restore

**Application:** Redeploy from a known-good commit:
```bash
git checkout <commit-sha>
kamal deploy -d production
```

## 15. Cost Optimization

### Staging
- Single droplet: ~$6-12/month (1-2GB RAM)
- Postgres runs as accessory (no additional cost)
- Domain/SSL: Free (Let's Encrypt)

### Production
- Application droplet: ~$12-24/month (2-4GB RAM recommended)
- Digital Ocean Postgres: ~$15/month (Basic 1GB) to ~$60/month (Production 4GB)
- Domain: ~$10-15/year
- Monitoring: $0-50/month depending on service

**Total estimated cost:** $30-100/month for production-ready setup

## 16. Promotion Workflow

Typical workflow for deploying features:

1. **Development:**
   ```bash
   git checkout -b feature/new-feature
   # Make changes, test locally
   bin/rails test
   git commit -am "Add new feature"
   ```

2. **Deploy to Staging:**
   ```bash
   git push origin feature/new-feature
   git checkout main
   git merge feature/new-feature
   git push origin main
   kamal deploy -d staging
   ```

3. **Test on Staging:**
   - Visit https://staging.covertext.app
   - Test the feature thoroughly
   - Check logs: `kamal app logs -d staging`

4. **Deploy to Production:**
   ```bash
   # Only after staging testing passes
   kamal deploy -d production
   ```

5. **Monitor Production:**
   ```bash
   kamal app logs -f -d production
   # Watch for errors, performance issues
   ```

## 17. Quick Reference

### Deployment Commands

| Task | Staging | Production |
|------|---------|------------|
| Initial setup | `kamal setup -d staging` | `kamal setup -d production` |
| Deploy | `kamal deploy -d staging` | `kamal deploy -d production` |
| View logs | `kamal app logs -f -d staging` | `kamal app logs -f -d production` |
| Rails console | `kamal app exec -d staging -i 'bin/rails console'` | `kamal app exec -d production -i 'bin/rails console'` |
| Run migrations | `kamal app exec -d staging 'bin/rails db:migrate'` | `kamal app exec -d production 'bin/rails db:migrate'` |
| Restart app | `kamal app boot -d staging` | `kamal app boot -d production` |
| Check status | `kamal app details -d staging` | `kamal app details -d production` |
| Postgres details | `kamal accessory details postgres -d staging` | N/A (managed by Digital Ocean) |

### Important URLs

| Environment | Application | Health Check |
|-------------|-------------|--------------|
| Staging | https://staging.covertext.app | https://staging.covertext.app/up |
| Production | https://covertext.app | https://covertext.app/up |

### Support Contacts

- **Hosting**: Digital Ocean support
- **DNS**: Your domain registrar
- **SMS**: Twilio support
- **Application**: Your development team

---

**Last Updated**: 2024
**Kamal Version**: 2.x
**Rails Version**: 8.1.2
6. Configure automated backups
7. Set up alerting
8. Add CI/CD pipeline

## Support

For issues:
1. Check logs: `kamal app logs`
2. Review Kamal docs: https://kamal-deploy.org
3. Check GitHub discussions
4. Review Traefik docs for proxy issues

## Reference

- **Kamal**: https://kamal-deploy.org
- **GHCR**: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- **Traefik**: https://doc.traefik.io/traefik/
- **Let's Encrypt**: https://letsencrypt.org/docs/
