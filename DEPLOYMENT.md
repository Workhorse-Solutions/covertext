# Deployment Guide: CoverText Staging Environment

This guide covers deploying CoverText to a staging environment using Kamal and GitHub Container Registry (GHCR).

## Prerequisites

- A Linux server (Ubuntu 22.04+ recommended) with:
  - Docker installed
  - SSH access via public key
  - Port 80 and 443 open to internet
  - At least 2GB RAM, 20GB disk

- GitHub account with:
  - Write access to the covertext repository
  - Personal Access Token (PAT) with `write:packages` scope

- Domain configured:
  - `staging.covertext.app` DNS A record pointing to your server IP

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

# Line 10: Replace with actual server IP
servers:
  web:
    - 123.45.67.89

# Line 21: Replace <GITHUB_USERNAME>
username: your-github-username

# Line 39: Replace server IP (same as web server)
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

# Twilio credentials
TWILIO_AUTH_TOKEN=your_twilio_auth_token_here

# Postgres password (generate a strong password)
POSTGRES_PASSWORD=your_strong_postgres_password_here
EOF

chmod 600 .kamal/secrets
```

**Important**: `.kamal/secrets` is in `.gitignore` - never commit it!

## 3. Initial Setup

### Registry Login

Login to GitHub Container Registry:

```bash
kamal registry login
```

This will prompt for your GHCR password (use the PAT you created).

### Server Setup

Initialize Kamal on your server (installs Docker, sets up network):

```bash
kamal setup
```

This will:
- Install Docker on the server (if needed)
- Create Docker network
- Pull the image
- Deploy the application
- Start the Kamal proxy (Traefik)

### Start Postgres Accessory

Boot the Postgres database:

```bash
kamal accessory boot postgres
```

Wait 10-20 seconds for Postgres to initialize.

### Run Database Migrations

```bash
kamal app exec "bin/rails db:create db:migrate db:seed"
```

## 4. Deploy Application

For initial deployment (already done if you ran `kamal setup`):

```bash
kamal deploy
```

For subsequent deployments:

```bash
# Build and deploy new version
kamal deploy

# Or with specific commands:
kamal build push    # Build and push image
kamal deploy        # Deploy to servers
```

## 5. Verify Deployment

### Check Application Status

```bash
# View running containers
kamal app details

# Tail application logs
kamal app logs -f

# Check Postgres
kamal accessory details postgres
```

### Access the Application

Visit: https://staging.covertext.app

Login with seed credentials:
- Email: john@reliableinsurance.example
- Password: password123

### Test Health Check

```bash
curl https://staging.covertext.app/up
```

Should return: `200 OK`

## 6. Configure Twilio Webhooks

Update your Twilio phone number webhooks to point to the staging server:

### Inbound SMS Webhook

- **URL**: `https://staging.covertext.app/webhooks/twilio/inbound`
- **HTTP Method**: POST
- **Content Type**: application/x-www-form-urlencoded

### Status Callback Webhook (Optional)

- **URL**: `https://staging.covertext.app/webhooks/twilio/status`
- **HTTP Method**: POST
- **Content Type**: application/x-www-form-urlencoded

## Common Commands

### Deployment

```bash
# Full deploy
kamal deploy

# Deploy with specific build
kamal build push
kamal deploy

# Rollback to previous version
kamal rollback

# Show deployed version
kamal app version
```

### Application Management

```bash
# Restart application
kamal app restart

# Stop application
kamal app stop

# Start application
kamal app start

# Open Rails console
kamal app exec --interactive --reuse "bin/rails console"

# Open bash shell
kamal app exec --interactive --reuse "bash"

# Run database migrations
kamal app exec "bin/rails db:migrate"
```

### Logs

```bash
# Tail application logs
kamal app logs -f

# View last 100 lines
kamal app logs --lines 100

# Tail Traefik proxy logs
kamal proxy logs -f

# Tail Postgres logs
kamal accessory logs postgres -f
```

### Database

```bash
# Connect to database
kamal accessory exec postgres "psql -U postgres -d covertext_production"

# Backup database
kamal accessory exec postgres "pg_dump -U postgres covertext_production" > backup.sql

# Restore database
cat backup.sql | kamal accessory exec postgres "psql -U postgres covertext_production"

# Restart Postgres
kamal accessory restart postgres
```

### Secrets Management

```bash
# Update secrets (edit .kamal/secrets then redeploy)
kamal env push

# View current environment (without secrets)
kamal app exec "env | sort"
```

## SSL/TLS with Let's Encrypt

Kamal proxy (Traefik) automatically handles:
- SSL certificate provisioning via Let's Encrypt
- Certificate renewal (every 60 days)
- HTTP → HTTPS redirect
- HTTPS/2 support

**Certificate storage**: `/root/.kamal/proxy/letsencrypt/` on server

**Important**: Ensure DNS is configured BEFORE first deploy, or Let's Encrypt will fail.

## Troubleshooting

### Deployment fails with "connection refused"

```bash
# Check if Docker is running on server
ssh root@123.45.67.89 "systemctl status docker"

# Check Kamal proxy
kamal proxy details
```

### SSL certificate fails to provision

- Verify DNS: `dig staging.covertext.app`
- Ensure ports 80 and 443 are open
- Check Traefik logs: `kamal proxy logs`
- Let's Encrypt rate limit: 5 failures per hour per domain

### Application won't start

```bash
# Check logs for errors
kamal app logs --lines 100

# Check if database is accessible
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.active?'"

# Verify environment variables
kamal app exec "env | grep -E 'DATABASE_URL|RAILS_MASTER_KEY'"
```

### Database connection errors

```bash
# Verify Postgres is running
kamal accessory details postgres

# Check Postgres logs
kamal accessory logs postgres --lines 50

# Restart Postgres
kamal accessory restart postgres
```

## Security Considerations

### Secrets Management

- ✅ `.kamal/secrets` is gitignored
- ✅ `config/master.key` is gitignored
- ❌ Never commit secrets to version control
- ✅ Use strong passwords (20+ characters)
- ✅ Rotate tokens/passwords periodically

### Server Hardening

Recommended (not covered here):
- Configure firewall (ufw/iptables)
- Disable root SSH login
- Enable fail2ban
- Configure automatic security updates
- Set up monitoring/alerting

### Database Backups

Set up automated backups:

```bash
# Example cron job (on server)
0 2 * * * docker exec covertext-postgres pg_dump -U postgres covertext_production | gzip > /backups/covertext_$(date +\%Y\%m\%d).sql.gz
```

## Production Deployment

This guide covers **staging only**. For production:

1. Use separate domain: `app.covertext.app`
2. Use separate server(s)
3. Add monitoring (e.g., New Relic, Datadog)
4. Add log aggregation (e.g., Papertrail, Logtail)
5. Set up separate Postgres server (not accessory)
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
