# Quick Start Guide

A complete walkthrough from fresh server to deployed site.

## Prerequisites

- A fresh Linux server (Debian/Ubuntu-based)
- A domain name pointed to your server's IP
- A static site ready to deploy (e.g., Eleventy project)

## Step 1: Generate SSH Key

On your local machine:

```bash
ssh-keygen -t ed25519 -C "myserver" -f ~/.ssh/myserver
```

## Step 2: Upload Key to Server

```bash
ssh-copy-id -i ~/.ssh/myserver.pub root@YOUR_SERVER_IP
```

## Step 3: Configure SSH Client

Add to `~/.ssh/config`:

```
Host myserver
    HostName YOUR_SERVER_IP
    User root
    IdentityFile ~/.ssh/myserver
```

Test the connection:

```bash
ssh myserver
```

## Step 4: Upload Setup Scripts

```bash
scp -r /path/to/server-setup/* myserver:/root/server-setup/
```

## Step 5: Run Server Setup

```bash
ssh myserver
cd /root/server-setup
chmod +x setup.sh deploy.sh modules/*.sh
./setup.sh
```

Follow the prompts to enter your domain, email, etc.

## Step 6: Update SSH Config

After setup completes, root SSH login is disabled. Update `~/.ssh/config` to use the deploy user:

```
Host myserver
    HostName YOUR_SERVER_IP
    User deploy
    IdentityFile ~/.ssh/myserver
```

Verify you can connect:

```bash
ssh myserver
```

## Step 7: Deploy Your Site

Copy `deploy.sh` to your Eleventy project:

```bash
cp /path/to/server-setup/deploy.sh ~/my-eleventy-site/
```

Build and deploy:

```bash
cd ~/my-eleventy-site
npm run build
./deploy.sh --host myserver --domain example.com --source ./_site
```

## Done

Your site is live at `https://yourdomain.com`

## Next Steps

- Set up CI/CD for automatic deployments - see [deployment.md](deployment.md)
- Review security settings - see [security.md](security.md)
- Learn maintenance commands - see [maintenance.md](maintenance.md)
