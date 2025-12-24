# Deploying Your Static Site

This guide covers deploying an Eleventy (or any static) site to your configured server.

> **Important:** The `deploy.sh` script runs from your **local machine** (where your static site is built), not on the server.

## Prerequisites

- Server configured with `setup.sh`
- SSH access to the deploy user
- Built static site (e.g., Eleventy `_site` directory)
- `deploy.sh` copied to your local project directory

## Setup

Copy `deploy.sh` from the server-setup repo to your local Eleventy project:

```bash
cp /path/to/server-setup/deploy.sh ~/my-eleventy-site/
```

## Method 1: Using the Deploy Script

From your local Eleventy project directory:

```bash
# Build your site first
npm run build

# Deploy to server
./deploy.sh --host myserver --domain example.com --source ./_site

# With short flags
./deploy.sh -h myserver -d example.com -s ./dist

# Dry run (preview without deploying)
./deploy.sh --host myserver --domain example.com --dry-run
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-h, --host` | Server hostname or IP | Required |
| `-d, --domain` | Domain name | Required |
| `-s, --source` | Local build directory | `./_site` |
| `-u, --user` | Remote user | `deploy` |
| `-p, --port` | SSH port | `22` |
| `-n, --dry-run` | Preview changes without deploying | - |

## Method 2: Manual rsync

```bash
rsync -avz --delete \
    ./_site/ \
    deploy@myserver:/var/www/html/
```

## Method 3: GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          
      - name: Install and Build
        run: |
          npm ci
          npm run build
          
      - name: Deploy
        uses: easingthemes/ssh-deploy@v4
        with:
          SSH_PRIVATE_KEY: ${{ secrets.DEPLOY_KEY }}
          REMOTE_HOST: ${{ secrets.SERVER_HOST }}
          REMOTE_USER: deploy
          SOURCE: "_site/"
          TARGET: "/var/www/html/"
          ARGS: "-avz --delete"
```

### Setting Up Secrets

1. Generate a deployment key: `ssh-keygen -t ed25519 -f deploy_key`
2. Add `deploy_key.pub` to server's `~deploy/.ssh/authorized_keys`
3. Add secrets to GitHub repo:
   - `DEPLOY_KEY`: Contents of `deploy_key` (private key)
   - `SERVER_HOST`: Your server's IP or hostname

## Post-Deployment

After deployment, your site is live. Verify with:

```bash
curl -I https://yourdomain.com
```

Check for:
- HTTP/2 200 response
- Security headers present
- Valid SSL certificate
