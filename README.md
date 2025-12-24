# Server Setup for Static Site Hosting

Modular bash scripts to configure a fresh Linux server with security best practices for hosting static websites.

## Features

- **System Hardening** - Secure SSH, kernel parameters, deploy user
- **UFW Firewall** - HTTP/HTTPS with rate limiting
- **Fail2ban** - Intrusion prevention for SSH and nginx
- **Nginx** - Optimized for static sites with security headers
- **Let's Encrypt** - Automatic SSL with auto-renewal
- **Unattended Upgrades** - Automatic security updates

## Quick Start

```bash
# Upload to server
scp -r ./* root@YOUR_SERVER_IP:/root/server-setup/

# SSH in and run
ssh root@YOUR_SERVER_IP
cd /root/server-setup
chmod +x setup.sh deploy.sh modules/*.sh
./setup.sh
```

The interactive setup will prompt for your domain, email, and other options.

## Project Structure

```
├── setup.sh              # Run on server (one-time configuration)
├── deploy.sh             # Run locally to deploy your site
├── config.env.example    # Example configuration file
├── docs/                 # Additional documentation
│   ├── quickstart.md     # Complete walkthrough guide
│   ├── ssh-setup.md      # SSH key generation guide
│   ├── deployment.md     # Deployment methods (rsync, CI/CD)
│   ├── security.md       # Security hardening reference
│   └── maintenance.md    # Server maintenance guide
└── modules/
    ├── utils.sh          # Shared utility functions
    ├── hardening.sh      # System hardening
    ├── firewall.sh       # UFW configuration
    ├── fail2ban.sh       # Intrusion prevention
    ├── nginx.sh          # Web server setup
    ├── ssl.sh            # SSL certificates
    └── updates.sh        # Unattended upgrades
```

**Note:** `setup.sh` and `modules/` are run on the server. `deploy.sh` is run from your local machine (where your static site is built).

## Configuration

Copy and edit the example config for non-interactive setup:

```bash
cp config.env.example config.env
vim config.env
./setup.sh
```

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your website domain | (required) |
| `ADMIN_EMAIL` | Email for Let's Encrypt | (required) |
| `SERVER_IP` | Server's public IP | (auto-detected) |
| `SSH_PORT` | SSH port | `22` |
| `DEPLOY_USER` | Username for deployments | `deploy` |
| `TIMEZONE` | Server timezone | `UTC` |
| `WEB_ROOT` | Web files directory | `/var/www` |

## Running Individual Modules

Each module can be run independently:

```bash
source config.env
sudo ./modules/firewall.sh
sudo ./modules/nginx.sh
# etc.
```

## Deployment

After server setup, deploy from your local Eleventy project directory:

```bash
# Copy deploy.sh to your project (one-time)
cp /path/to/server-setup/deploy.sh ~/my-eleventy-site/

# Build and deploy
cd ~/my-eleventy-site
npm run build
./deploy.sh --host YOUR_SERVER_IP --source ./_site
```

See [docs/deployment.md](docs/deployment.md) for CI/CD integration and other methods.

## Documentation

- [Quick Start Guide](docs/quickstart.md) - Complete walkthrough from fresh server to deployed site
- [SSH Setup Guide](docs/ssh-setup.md) - Generate keys and connect to your server
- [Deployment Guide](docs/deployment.md) - Deploy via script, rsync, or GitHub Actions
- [Security Reference](docs/security.md) - Details on all hardening measures
- [Maintenance Guide](docs/maintenance.md) - Logs, backups, troubleshooting

## License

Licensed under the [MIT license](LICENSE).
