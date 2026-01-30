# Deployment Guide: CoverText Production

This guide covers deploying CoverText to production using Kamal and GitHub Container Registry (GHCR).

## Overview

CoverText uses Kamal for production deployment:

- **Production** (`covertext.app`)
  - DigitalOcean Droplet: 2 GB RAM / 1 vCPU / 70 GB Disk (SFO2)
  - DigitalOcean Managed PostgreSQL: 1 GB RAM / 1 vCPU / 10 GiB Disk (SFO2 - PostgreSQL 18)
  - Solid Queue/Cache/Cable using SQLite on persistent volume
  - Production Twilio API key
  - Deploy with: `kamal deploy -d production`

## Prerequisites

**Production Infrastructure:**

- DigitalOcean Droplet (Ubuntu 24.04 LTS x64) with:
  - 2 GB RAM / 1 vCPU / 70 GB Disk minimum
  - Docker installed
  - SSH access via public key
  - Port 80 and 443 open to internet
  - Server IP: 159.65.110.3

- DigitalOcean Managed PostgreSQL Database:
  - 1 GB RAM / 1 vCPU / 10 GiB Disk minimum
  - PostgreSQL 18
  - Located in same region (SFO2) for lower latency

- GitHub account with:
  - Write access to the covertext repository
  - Personal Access Token (PAT) with `write:packages` scope

- DNS configured:
  - `covertext.app` → Production server IP (159.65.110.3)
  - A record verified with `dig covertext.app`

- DigitalOcean Managed Postgres connection string from database cluster settings

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

### Update config/deploy.production.yml

This file should already be configured with:

```yaml
# Server IP
servers:
  web:
    - 159.65.110.3

# Container registry
image: ghcr.io/jrmyward/covertext

registry:
  server: ghcr.io
  username: jrmyward

# SSL and domain
proxy:
  ssl: true
  host: covertext.app

# Persistent volume for SQLite databases and Active Storage
volumes:
  - "volume_sfo2_01:/rails/storage"

# Environment configuration
env:
  clear:
    SOLID_QUEUE_IN_PUMA: true
    DB_HOST: DB_HOST  # Will be provided via credentials
```

### Create .kamal/secrets file

Create the secrets file (NOT committed to git):

```bash
mkdir -p .kamal
cat > .kamal/secrets << 'EOF'
# GitHub Container Registry password (your PAT)
KAMAL_REGISTRY_PASSWORD=ghp_your_github_pat_here

# Rails master key (from config/credentials/production.key)
RAILS_MASTER_KEY=$(cat config/credentials/production.key)
EOF

chmod 600 .kamal/secrets
```

**Important**: `.kamal/secrets` is in `.gitignore` - never commit it!

### Configure Rails Credentials

**Production Credentials:**

Edit production credentials:
```bash
bin/rails credentials:edit --environment production
```

Add:
```yaml
# Twilio API credentials
twilio:
  account_sid: SKxxxxxxxx_production_api_key_sid
  auth_token: your_production_api_key_secret

# Database connection
database:
  url: postgres://doadmin:password@your-db-cluster.db.ondigitalocean.com:25060/covertext_production?sslmode=require
```

Save and exit. The encrypted file is committed to git, but `config/credentials/production.key` must be kept secure and shared with your team via secure channels (1Password, etc.).

⚠️ **Important:**
- Twilio credentials MUST be in Rails encrypted credentials
- Database URL includes the full connection string from DigitalOcean
- The application checks credentials first, then falls back to ENV vars

**Fallback Only: Environment Variables**

If you absolutely must use ENV vars (not recommended), add to `.kamal/secrets`:
```bash
TWILIO_ACCOUNT_SID=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token_or_api_key_secret
```

## 3. Initial Setup

### Registry Login

Login to GitHub Container Registry:

```bash
kamal registry login
```

This will prompt for your GHCR password (use the PAT you created).

### Production Setup

Initialize Kamal on production server:

```bash
kamal setup -d production
```

This will:
- Install Docker on the server (if needed)
- Create Docker network
- Create persistent volume: `volume_sfo2_01`
- Pull the image from GHCR
- Deploy the application container
- Start kamal-proxy with SSL (Let's Encrypt)
- Configure health checks

**Wait for SSL Certificate:** Let's Encrypt will automatically provision SSL certificates. This may take 1-2 minutes. You can verify DNS is correctly pointing to your server:

```bash
dig covertext.app
# Should return A record: 159.65.110.3
```

### Run Database Migrations

Once deployment completes, run migrations (includes Solid Cache/Queue/Cable SQLite databases):

```bash
kamal app exec -d production 'bin/rails db:prepare'
```

This prepares both:
- PostgreSQL primary database on DigitalOcean
- SQLite databases for Solid Queue/Cache/Cable on persistent volume

### Seed the Database (Optional)

If you need initial data:

```bash
kamal app exec -d production 'bin/rails db:seed'
```

## 4. Deploy Application

### Deploy to Production

```bash
kamal deploy -d production
```

This will:
- Build Docker image locally
- Push to GHCR
- Deploy to production server (159.65.110.3)
- Perform zero-downtime restart

### Individual Build Steps

```bash
# Build and push image only
kamal build push -d production

# Deploy without rebuilding
kamal deploy -d production --skip-push
```

## 5. Verify Deployment

### Check Application Status

```bash
# View running containers
kamal app details -d production

# Tail application logs
kamal app logs -f -d production

# Check specific number of lines
kamal app logs -d production --lines 100
```

### Access the Application

**Production:** https://covertext.app

If SSL is still provisioning, you'll see a certificate warning. Wait 1-2 minutes and refresh.

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

```bash
# Rails console
kamal app exec -d production -i 'bin/rails console'

# Database migrations
kamal app exec -d production 'bin/rails db:migrate'

# Run a rake task
kamal app exec -d production 'bin/rails db:seed'

# Check database status
kamal app exec -d production 'bin/rails db:version'
```

### Viewing Logs

```bash
# Application logs (follow)
kamal app logs -f -d production

# Last 100 lines
kamal app logs -d production --lines 100

# Filter for errors
kamal app logs -d production --lines 500 | grep ERROR
```

### Restarting Services

```bash
# Restart application
kamal app boot -d production

# Restart proxy
kamal proxy reboot -d production

# Full redeploy
kamal deploy -d production
```

### Rolling Back

```bash
# List recent versions
kamal app images -d production

# Rollback to specific version
kamal rollback -d production "v1.0.0"
```

## 8. Troubleshooting

### Database Connection Issues

**Verify credentials are loaded:**
```bash
kamal app exec -d production -i 'bin/rails console'
# Then: Rails.application.credentials.database
```

**Check Digital Ocean database firewall:**
- Ensure production server IP (159.65.110.3) is allowed
- Verify connection string includes `sslmode=require`
- Test from server:
```bash
kamal app exec -d production 'bin/rails runner "puts ActiveRecord::Base.connection.execute(\"SELECT 1\").to_a"'
```

### Application Won't Start

```bash
# Check logs for errors
kamal app logs -d production --lines 200

# Check container status
kamal app details -d production

# Restart application
kamal app boot -d production

# Check health endpoint
curl https://covertext.app/up
```

### SSL Certificate Issues

```bash
# Check proxy status
kamal proxy details -d production

# Verify DNS
dig covertext.app
# Should show: 159.65.110.3

# Restart proxy to regenerate cert
kamal proxy reboot -d production

# Check kamal-proxy logs
kamal proxy logs -d production

# Let's Encrypt can take 1-2 minutes - be patient!
```

### Image Build Failures

```bash
# Check Docker build output
kamal build push -d production --verbose

# Clear builder cache
docker builder prune -a

# Verify GHCR authentication
kamal registry login
```

### Twilio Webhook Failures

```bash
# Check application logs for webhook errors
kamal app logs -d production | grep -i twilio

# Verify credentials are loaded
kamal app exec -d production -i 'bin/rails console'
# Then: Rails.application.credentials.twilio

# Test webhook endpoint (should return 405 Method Not Allowed for GET)
curl https://covertext.app/webhooks/twilio/inbound
```

### SQLite Database Issues (Solid Queue/Cache/Cable)

```bash
# Check if volume is mounted correctly
kamal app exec -d production 'ls -la /rails/storage'

# Verify SQLite files exist
kamal app exec -d production 'ls -lh /rails/storage/*.sqlite3'

# Check SQLite file permissions
kamal app exec -d production 'stat /rails/storage/covertext_production_queue.sqlite3'

# If corrupted, delete and rebuild (safe - cache/queue data is ephemeral)
kamal app exec -d production 'rm /rails/storage/covertext_production_cache.sqlite3'
kamal app exec -d production 'bin/rails db:prepare'
```

## 9. Architecture: SQLite for Solid Queue/Cache/Cable

CoverText uses **SQLite for Solid Cache, Solid Queue, and Solid Cable** instead of Postgres or Redis. This is Rails 8's recommended approach.

### Why SQLite for Cache/Queue/Cable?

✅ **Performance**: Faster than Postgres for simple read/write operations (no network overhead)
✅ **Cost**: Smaller managed Postgres needed (only app data, not cache/queue churn)
✅ **Simplicity**: No Redis, no connection pooling issues, no additional services
✅ **Rails 8 Native**: This is the default, battle-tested configuration

### Database Architecture

**Primary (PostgreSQL):**
- Application data: agencies, clients, conversations, messages, etc.
- DigitalOcean Managed PostgreSQL (1 GB RAM / 1 vCPU / 10 GiB Disk)
- Requires backups
- Connection via SSL

**Cache/Queue/Cable (SQLite):**
- Ephemeral data: cached values, background jobs, WebSocket connections
- Stored in persistent DigitalOcean volume: `volume_sfo2_01:/rails/storage`
- Files: `storage/covertext_production_{cache,queue,cable}.sqlite3`
- No backups needed (can be safely deleted and rebuilt)
- Runs in same process as web server (`SOLID_QUEUE_IN_PUMA=true`)

### Persistent Volume

Production uses a DigitalOcean block storage volume:
- Volume name: `volume_sfo2_01`
- Mounted at: `/rails/storage`
- Contains: SQLite databases + Active Storage uploads
- Survives container restarts and redeployments
- **Important**: Back up Active Storage files separately if needed
- Persisted via Docker volumes

### File Locations

**On Host:**
- `/var/lib/covertext/staging/db/*.sqlite3`
- `/var/lib/covertext/production/db/*.sqlite3`

**In Container:**
- `/rails/db/production_cache.sqlite3`
- `/rails/db/production_queue.sqlite3`
- `/rails/db/production_cable.sqlite3`

### When to Switch to Postgres

Only if you need:
- Multiple app servers with shared queue/cache
## 10. Production Infrastructure Details

### DigitalOcean Droplet

**Specifications:**
- Size: 2 GB RAM / 1 Intel vCPU / 70 GB Disk
- Region: SFO2 (San Francisco)
- OS: Ubuntu 24.04 (LTS) x64
- IP Address: 159.65.110.3
- Networking: 100 GB transfer included

**Persistent Volume:**
- Volume: `volume_sfo2_01`
- Mount point: `/rails/storage`
- Contains: SQLite databases + Active Storage files

### DigitalOcean Managed PostgreSQL

**Specifications:**
- Size: 1 GB RAM / 1 vCPU / 10 GiB Disk
- Region: SFO2 (San Francisco) - same as droplet for low latency
- Version: PostgreSQL 18
- SSL: Required
- Backups: Automated (configure in DO console)

**Firewall Configuration:**
- Allow connections from production droplet: 159.65.110.3
- SSL/TLS required for all connections

**Connection:**
- Configured via Rails encrypted credentials
- Format: `postgres://doadmin:password@host:25060/covertext_production?sslmode=require`
- Obtained from DigitalOcean database cluster "Connection Details"

## 11. Security Checklist

- [ ] `.kamal/secrets` is in `.gitignore` and NOT committed
- [ ] `config/credentials/production.key` is securely stored (1Password, etc.)
- [ ] GitHub PAT has minimal permissions (read:packages, write:packages)
- [ ] Twilio uses API key with appropriate permissions
- [ ] DigitalOcean database has firewall rules limiting access to 159.65.110.3 only
- [ ] Database connection uses `sslmode=require`
- [ ] Server SSH keys are secured and backed up
- [ ] DNS records are protected (registrar 2FA enabled)
- [ ] Persistent volume has appropriate permissions

## 12. Maintenance

### Updating Dependencies

```bash
bundle update
git commit -am "Update gems"
kamal deploy -d production
```

### Database Backups

**PostgreSQL (Primary):**

DigitalOcean automated backups:
1. Navigate to your database cluster in DO console
2. Enable "Automated Backups"
3. Choose retention period (7 days minimum recommended)
4. Schedule: Daily

Manual backup:
```bash
# From local machine with psql installed
pg_dump "postgres://doadmin:password@host:25060/covertext_production?sslmode=require" > backup_$(date +%Y%m%d).sql
```

**SQLite (Solid Queue/Cache/Cable):**
No backups needed - ephemeral data that can be safely deleted and rebuilt.

### Storage Backups (Active Storage)

**Important:** Insurance cards, PDFs, and other uploaded files need separate backups:

```bash
# Manual backup from droplet
ssh root@159.65.110.3 "tar -czf /tmp/storage-backup.tar.gz -C /mnt/volume_sfo2_01 ."
scp root@159.65.110.3:/tmp/storage-backup.tar.gz ./storage-backup-$(date +%Y%m%d).tar.gz

# Restore
scp ./storage-backup.tar.gz root@159.65.110.3:/tmp/
ssh root@159.65.110.3 "tar -xzf /tmp/storage-backup.tar.gz -C /mnt/volume_sfo2_01"
```

Consider setting up automated backups to S3 or DigitalOcean Spaces.

### Secrets Management

```bash
# Update environment variables
kamal env push -d production

# View current environment (without secrets)
kamal app exec -d production "env | sort"
```

### Updating Rails Credentials

```bash
bin/rails credentials:edit --environment production
# Make changes, save, commit encrypted file
git commit -am "Update production credentials"
kamal deploy -d production
```

## 13. SSL/TLS with Let's Encrypt

kamal-proxy automatically handles:
- SSL certificate provisioning via Let's Encrypt
- Certificate renewal (every 60 days)
- HTTP → HTTPS redirect
- HTTP/2 support

**Certificate storage**: Managed by kamal-proxy on the droplet

**Important**: DNS must be configured and pointing to 159.65.110.3 BEFORE first deploy, or Let's Encrypt will fail. Verify with:
```bash
dig covertext.app
# Should return A record: 159.65.110.3
```

If HTTPS doesn't work immediately after `kamal setup`, wait 1-2 minutes for Let's Encrypt provisioning to complete.

## 14. Monitoring and Logs

### Application Logs

```bash
# Follow logs in real-time
kamal app logs -f -d production

# Search for errors
kamal app logs -d production --lines 500 | grep -i error

# Check Solid Queue jobs
kamal app logs -d production | grep -i "solid queue"
```

### Health Checks

The application exposes a health endpoint:
```bash
curl https://covertext.app/up
# Should return: 200 OK
```

Monitor this endpoint with:
- UptimeRobot
- Pingdom
- StatusCake
- DigitalOcean monitoring

## 15. Disaster Recovery

### Complete Production Rebuild

If production needs complete rebuild:

```bash
# 1. Back up database and storage first!
pg_dump "postgres://..." > backup.sql
ssh root@159.65.110.3 "tar -czf /tmp/storage.tar.gz -C /mnt/volume_sfo2_01 ."

# 2. Destroy everything
kamal app remove -d production
kamal proxy remove -d production

# 3. Rebuild from scratch
kamal setup -d production
kamal app exec -d production 'bin/rails db:prepare'

# 4. Restore data if needed
psql "postgres://..." < backup.sql
scp storage.tar.gz root@159.65.110.3:/tmp/
ssh root@159.65.110.3 "tar -xzf /tmp/storage.tar.gz -C /mnt/volume_sfo2_01"
```

### Database Restore

```bash
# From backup file
psql "postgres://doadmin:password@host:25060/covertext_production?sslmode=require" < backup.sql

# Or restore from DigitalOcean automated backup via DO console
```

# Clean up host volumes (optional - will lose all data)
ssh root@staging-server "rm -rf /var/lib/covertext/staging"

# Rebuild from scratch
kamal setup -d staging
kamal app exec -d staging 'bin/rails db:prepare db:seed'
```

### Production Recovery

**SQLite:** Rebuild (safe - ephemeral data):
```bash
kamal app exec -d production 'rm /rails/storage/covertext_production_*.sqlite3'
kamal app exec -d production 'bin/rails db:prepare'
```

## 16. Cost Optimization

### Production Infrastructure Costs

**DigitalOcean Droplet:**
- Size: 2 GB RAM / 1 vCPU / 70 GB Disk
- Cost: ~$18/month
- Includes: 100 GB transfer

**DigitalOcean Managed PostgreSQL:**
- Size: 1 GB RAM / 1 vCPU / 10 GiB Disk
- Cost: ~$15/month
- Includes: Automated backups, high availability option

**DigitalOcean Block Storage Volume:**
- Volume: volume_sfo2_01 for persistent storage
- Included in droplet or ~$10/month if additional capacity needed

**Domain & SSL:**
- Domain: ~$10-15/year
- SSL: Free (Let's Encrypt via kamal-proxy)

**Total estimated cost: ~$35-50/month**

**Cost savings vs traditional stack:**
- No Redis: -$15-50/month
- No separate block storage needed initially: -$10/month
- Smaller Postgres instance: -$15-30/month (only app data, not cache/queue)
- **Save $40-90/month** by using Rails 8's Solid Queue/Cache/Cable with SQLite

## 17. Deployment Workflow

Typical workflow for deploying features:

1. **Development:**
   ```bash
   git checkout -b feature/new-feature
   # Make changes, test locally with bin/dev
   bin/rails test
   git commit -am "Add new feature"
   git push origin feature/new-feature
   ```

2. **Merge to Main:**
   ```bash
   # Create PR, get review, merge to main
   git checkout main
   git pull origin main
   ```

3. **Deploy to Production:**
   ```bash
   kamal deploy -d production
   ```

4. **Monitor Production:**
   ```bash
   kamal app logs -f -d production
   # Watch for errors, performance issues
   # Check https://covertext.app/up
   ```

5. **Rollback if Needed:**
   ```bash
   kamal app images -d production
   kamal rollback -d production "previous-version"
   ```

## 18. Quick Reference

### Common Commands

```bash
# Deploy
kamal deploy -d production

# View logs
kamal app logs -f -d production

# Rails console
kamal app exec -d production -i 'bin/rails console'

# Run migrations
kamal app exec -d production 'bin/rails db:migrate'

# Restart app
kamal app boot -d production

# Check status
kamal app details -d production
kamal proxy details -d production

# Check persistent volume
ssh root@159.65.110.3 "ls -lh /mnt/volume_sfo2_01"
```

### Database Architecture Reference

| Component | Type | Location | Backups Needed? |
|-----------|------|----------|-----------------|
| Application data | PostgreSQL 18 | DigitalOcean Managed | ✅ Yes (automated) |
| Solid Cache | SQLite | `/rails/storage/covertext_production_cache.sqlite3` | ❌ No (ephemeral) |
| Solid Queue | SQLite | `/rails/storage/covertext_production_queue.sqlite3` | ❌ No (ephemeral) |
| Solid Cable | SQLite | `/rails/storage/covertext_production_cable.sqlite3` | ❌ No (ephemeral) |
| Active Storage | Files | `/rails/storage/` (DigitalOcean volume) | ✅ Yes (manual) |

### Infrastructure Reference

| Component | Specification | IP/URL |
|-----------|---------------|--------|
| Droplet | 2GB RAM / 1 vCPU / Ubuntu 24.04 | 159.65.110.3 |
| PostgreSQL | 1GB RAM / 1 vCPU / PostgreSQL 18 | Managed by DO |
| Volume | volume_sfo2_01 | `/rails/storage` |
| Application | https://covertext.app | |
| Health Check | https://covertext.app/up | |

---

**Last Updated**: January 2026
**Kamal Version**: 2.x
**Rails Version**: 8.1.2
**Deployment Target**: DigitalOcean SFO2
