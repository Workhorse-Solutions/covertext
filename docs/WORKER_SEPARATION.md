# Solid Queue Worker Separation Architecture

## Overview

CoverText uses a **two-container architecture** for staging and production deployments:
- **Web container**: Runs Puma HTTP server only
- **Worker container**: Runs Solid Queue supervisor for background job processing

This separation provides better resource isolation, independent scaling, and clearer operational boundaries.

## Why We Separated Web and Worker

### Original Architecture (Single Container)
Initially, CoverText ran Solid Queue **inside the Puma process** using:
```ruby
# config/puma.rb
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"
```

**Limitations:**
- No independent scaling (web traffic vs job processing)
- Resource contention between HTTP requests and background jobs
- Harder to monitor and troubleshoot issues
- Single point of failure

### New Architecture (Two Containers)
Now we use dedicated containers:
- **Web**: HTTP only, managed by kamal-proxy with SSL
- **Worker**: Background jobs only, runs `bin/rails solid_queue:start`

**Benefits:**
- Independent horizontal scaling (scale workers separately from web)
- Better resource isolation (CPU/memory)
- Clearer logs and metrics
- Separate health monitoring
- Production-ready topology

## Configuration

### Kamal Deployment Configuration

In `config/deploy.staging.yml` (and `config/deploy.production.yml`):

```yaml
servers:
  web:
    hosts:
      - 159.65.70.168
    labels:
      traefik.http.routers.covertext-web-staging.entrypoints: websecure
      traefik.http.routers.covertext-web-staging.rule: Host(`staging.covertext.app`)
      traefik.http.routers.covertext-web-staging.tls: true
      traefik.http.routers.covertext-web-staging.tls.certresolver: letsencrypt
    options:
      network: "private"
  worker:
    hosts:
      - 159.65.70.168
    cmd: bin/rails solid_queue:start
    options:
      network: "private"

env:
  clear:
    # Disable Solid Queue in Puma (web container)
    SOLID_QUEUE_IN_PUMA: false
    # Run Solid Queue in async mode (required for SQLite)
    SOLID_QUEUE_SUPERVISOR_MODE: async
```

### Critical Environment Variables

#### `SOLID_QUEUE_IN_PUMA`
- **Purpose**: Controls whether Solid Queue runs inside Puma
- **Web container**: `false` (do not run Solid Queue)
- **Worker container**: Ignored (worker doesn't run Puma)
- **Important**: Must be string `"false"`, not boolean, and checked with `== "true"`

**Why the string check matters:**
```ruby
# ❌ WRONG - ENV vars are strings, so "false" is truthy
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# ✅ CORRECT - Explicit string comparison
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"
```

#### `SOLID_QUEUE_SUPERVISOR_MODE`
- **Purpose**: Controls how Solid Queue spawns workers/dispatchers
- **Values**: `fork` (default) or `async`
- **Required setting**: `async` for SQLite-backed queue
- **Worker container**: Must be set to `"async"`

**Why async mode is required:**

Solid Queue supports two supervisor modes:

1. **Fork mode** (default, production recommended):
   - Spawns workers/dispatchers as separate processes
   - Better isolation and crash recovery
   - **Requires PostgreSQL or MySQL** (multi-process safe)
   - **Not compatible with SQLite** (causes "database is locked" errors)

2. **Async mode** (SQLite compatible):
   - Runs workers/dispatchers as threads in single process
   - Required for SQLite (single-process database)
   - Slightly less isolation but acceptable for staging
   - **Only way to use SQLite with Solid Queue**

**Configuration location:**
- ✅ **Set via environment variable** `SOLID_QUEUE_SUPERVISOR_MODE=async`
- ❌ **Not configurable in Rails config** - `config.solid_queue.supervisor_mode` doesn't exist

## SQLite Configuration for Concurrent Access

When using SQLite for Solid Queue (staging), you must enable **WAL (Write-Ahead Logging) mode** to allow concurrent reads during writes:

### Database Configuration

In `config/database.yml`:

```yaml
sqlite: &sqlite
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  timeout: 5000
  flags:
    - SQLITE_OPEN_READWRITE
    - SQLITE_OPEN_CREATE
    - SQLITE_OPEN_URI
  variables:
    # Critical for concurrent access
    pragma_journal_mode: WAL
    pragma_synchronous: NORMAL
    pragma_busy_timeout: 5000
    pragma_mmap_size: 134217728
    pragma_cache_size: 2000

staging:
  primary:
    <<: *default
    host: covertext-postgres-staging
    database: covertext_staging
  cache:
    <<: *sqlite
    database: data/staging_cache.sqlite3
  queue:
    <<: *sqlite
    database: data/staging_queue.sqlite3
  cable:
    <<: *sqlite
    database: data/staging_cable.sqlite3
```

**Why WAL mode matters:**
- **Without WAL**: Single writer blocks all readers → "database is locked" errors
- **With WAL**: Readers can access database while writes happen → concurrent access
- **Trade-off**: Creates additional `-wal` and `-shm` files (acceptable)

## Container Initialization

### Docker Entrypoint Schema Loading

The `bin/docker-entrypoint` script ensures SQLite databases are initialized:

```bash
#!/bin/bash -e

mkdir -p data

if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
  # Load SQLite schemas (idempotent - safe to run multiple times)
  ./bin/rails db:create:cache 2>/dev/null || true
  ./bin/rails db:schema:load:cache
  ./bin/rails db:create:queue 2>/dev/null || true
  ./bin/rails db:schema:load:queue
  ./bin/rails db:create:cable 2>/dev/null || true
  ./bin/rails db:schema:load:cable
fi

exec "${@}"
```

**Why schemas must always load:**
- ✅ `db:schema:load:*` is idempotent (safe to run multiple times)
- ✅ Creates tables if missing, does nothing if they exist
- ❌ Previous conditional check (`if [ ! -f "..." ]`) failed when files existed but were empty
- ❌ Led to "Could not find table 'solid_queue_jobs'" errors

### Pre-deploy Hook

The `.kamal/hooks/pre-deploy` script creates volume directories:

```bash
#!/bin/bash -e

# Create directories with correct ownership before deployment
mkdir -p /var/lib/covertext/staging/data
mkdir -p /storage
chown -R 1000:1000 /var/lib/covertext/staging/data
chown -R 1000:1000 /storage
```

**Why this is needed:**
- Docker volumes must exist before container starts
- Files must be owned by Rails user (uid 1000) inside container
- Prevents permission errors during schema loading

## Common Issues and Solutions

### Issue 1: "database is locked" Errors

**Symptoms:**
```
SQLite3::BusyException: database is locked
ActiveRecord::StatementTimeout
```

**Root cause**: Multiple processes trying to access SQLite simultaneously

**Solution**: Use async supervisor mode
```yaml
env:
  clear:
    SOLID_QUEUE_SUPERVISOR_MODE: async
```

**Why it works**: Async mode uses threads (single process) instead of forked processes, eliminating multi-process SQLite contention.

### Issue 2: "Could not find table 'solid_queue_jobs'"

**Symptoms:**
```
ActiveRecord::StatementInvalid: Could not find table 'solid_queue_jobs'
```

**Root cause**: SQLite file exists but tables weren't created

**Solution**: Always run schema loading in docker-entrypoint (it's idempotent)
```bash
# Remove conditional checks, always load
./bin/rails db:schema:load:queue
```

### Issue 3: NoMethodError: undefined method `instantiate' for nil

**Symptoms:**
```
NoMethodError: undefined method `instantiate' for nil
bin/rails aborted!
Tasks: TOP => solid_queue:start
```

**Root cause**: Solid Queue configuration error, usually related to queue.yml or startup race conditions

**Solution**: 
- Ensure `config/queue.yml` has valid configuration
- Let supervisor auto-restart (usually self-recovers after initial startup)
- Verify `SOLID_QUEUE_SUPERVISOR_MODE=async` is set

### Issue 4: Web Container Running Solid Queue

**Symptoms:**
```
# In web container logs:
SolidQueue-1.3.1 Started Supervisor
```

**Root cause**: `SOLID_QUEUE_IN_PUMA` check is wrong or not set

**Solution**: Fix puma.rb check
```ruby
# config/puma.rb
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"
```

And set in deploy config:
```yaml
env:
  clear:
    SOLID_QUEUE_IN_PUMA: false
```

## Deployment Workflow

### Deploy with Worker Separation

```bash
# 1. Commit changes
git add -A
git commit -m "Your changes"
git push

# 2. Deploy to staging
kamal deploy -d staging

# 3. Verify both containers running
kamal app details -d staging

# 4. Check web container (should have 0 SolidQueue logs)
kamal app logs -d staging --roles web --since 1m | grep -i solidqueue | wc -l

# 5. Check worker container (should show Supervisor(async))
kamal worker-logs -d staging --since 1m | grep "Supervisor"

# 6. Test site is responding
curl -I https://staging.covertext.app
```

### Useful Kamal Commands

```bash
# Check container status
kamal app details -d staging

# View web logs
kamal app logs -d staging --roles web --since 5m

# View worker logs (uses alias from deploy config)
kamal worker-logs -d staging --since 5m

# Restart worker only
kamal app stop -d staging --roles worker
kamal app start -d staging --roles worker

# Execute command in web container
kamal app exec -d staging --roles web 'bin/rails console'

# Monitor for errors
kamal worker-logs -d staging --since 5m | grep -i error
```

## Performance Tuning

### SQLite Busy Timeout

If you see occasional locking errors even in async mode, increase busy timeout:

```yaml
# config/database.yml
sqlite: &sqlite
  variables:
    pragma_busy_timeout: 10000  # Increase from 5000ms to 10000ms
```

### Thread Pool Size

Adjust worker thread count based on workload:

```yaml
# config/queue.yml
production:
  workers:
    - queues: "*"
      threads: 5        # Increase for more concurrent job processing
      polling_interval: 0.1
```

**Trade-offs:**
- More threads = more concurrent jobs but higher memory/CPU
- SQLite has limits on concurrent writes (even with WAL)
- Monitor memory usage when increasing threads

### Production Recommendation: Use PostgreSQL for Queue

For production, consider migrating Solid Queue to PostgreSQL:

```yaml
# config/database.yml
production:
  queue:
    <<: *default
    host: <%= ENV['DATABASE_HOST'] %>
    database: covertext_production
    # Use same Postgres cluster as primary
```

**Benefits:**
- No SQLite limitations
- Can use fork mode (better process isolation)
- Better concurrency (Postgres handles it natively)
- Unified database backup strategy

**Change in deploy config:**
```yaml
env:
  clear:
    # Can remove these with Postgres queue:
    # SOLID_QUEUE_SUPERVISOR_MODE: async  # Use default 'fork' mode
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Digital Ocean Droplet                     │
│                                                              │
│  ┌────────────────┐              ┌─────────────────────┐   │
│  │  kamal-proxy   │              │   PostgreSQL 16     │   │
│  │   (port 80)    │──┐           │   (accessory)       │   │
│  │  Let's Encrypt │  │           │  - Primary DB       │   │
│  └────────────────┘  │           └─────────────────────┘   │
│                      │                                       │
│                      ├──► ┌───────────────────────────┐    │
│                      │    │   Web Container           │    │
│                      │    │   - Puma HTTP server      │    │
│                      │    │   - SOLID_QUEUE_IN_PUMA:  │    │
│                      │    │     false                 │    │
│                      │    │   - Rails app code        │    │
│                      │    └───────────────────────────┘    │
│                      │            │                         │
│                      │            │ Enqueue jobs            │
│                      │            ▼                         │
│  ┌──────────────────┴────────────────────────┐            │
│  │     Shared Volume: /var/lib/covertext/    │            │
│  │                    staging/data/           │            │
│  │  - staging_cache.sqlite3                  │            │
│  │  - staging_queue.sqlite3 ◄────┐           │            │
│  │  - staging_cable.sqlite3      │           │            │
│  │                                │           │            │
│  │  WAL Mode: Concurrent Access  │           │            │
│  └───────────────────────────────┼───────────┘            │
│                                   │                         │
│                      ┌────────────┴──────────────┐         │
│                      │   Worker Container        │         │
│                      │   - bin/rails             │         │
│                      │     solid_queue:start     │         │
│                      │   - Supervisor(async)     │         │
│                      │   - SOLID_QUEUE_          │         │
│                      │     SUPERVISOR_MODE: async│         │
│                      │   - Processes jobs from   │         │
│                      │     SQLite queue          │         │
│                      └───────────────────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting Checklist

When debugging worker issues:

- [ ] Both containers running: `kamal app details -d staging`
- [ ] Web container isolated: `kamal app logs -d staging --roles web | grep -i solidqueue` → should be empty
- [ ] Worker showing async mode: `kamal worker-logs -d staging | grep "Supervisor(async)"`
- [ ] SQLite WAL mode enabled in database.yml
- [ ] SOLID_QUEUE_SUPERVISOR_MODE=async set in deploy config
- [ ] SOLID_QUEUE_IN_PUMA=false (or removed) in deploy config
- [ ] Pre-deploy hook creating volume directories
- [ ] Schema loading in docker-entrypoint (not conditional)
- [ ] No "database is locked" errors in last 2 minutes
- [ ] Site responding: `curl -I https://staging.covertext.app`

## References

- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [SQLite WAL Mode](https://www.sqlite.org/wal.html)
- [Kamal Documentation](https://kamal-deploy.org/)
- [Rails Multi-Database Guide](https://guides.rubyonrails.org/active_record_multiple_databases.html)
