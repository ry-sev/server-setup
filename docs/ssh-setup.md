# SSH Key Setup Guide

This guide covers generating SSH keys and connecting to a fresh server.

> **Note:** You only need **one SSH key**. The setup script automatically copies your key from root to the deploy user.

## 1. Generate SSH Key (Local Machine)

```bash
# Replace "myserver" with your preferred key name
ssh-keygen -t ed25519 -C "myserver" -f ~/.ssh/myserver
```

This creates:
- `~/.ssh/myserver` - Private key (keep secret, never share)
- `~/.ssh/myserver.pub` - Public key (upload to server)

## 2. Upload Key to Server

After provisioning a fresh server, upload your public key:

```bash
# Using ssh-copy-id (recommended)
ssh-copy-id -i ~/.ssh/myserver.pub root@YOUR_SERVER_IP
```

Or manually:

```bash
ssh root@YOUR_SERVER_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
cat ~/.ssh/myserver.pub | ssh root@YOUR_SERVER_IP "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 3. Configure SSH Client (Local Machine)

Add to `~/.ssh/config` for easier connections:

```
Host myserver
    HostName YOUR_SERVER_IP
    User root
    IdentityFile ~/.ssh/myserver
```

Now connect with just:

```bash
ssh myserver
```

## 4. Upload and Run Setup Scripts

```bash
# Copy scripts to server
scp -r /path/to/server-setup/* myserver:/root/server-setup/

# Connect and run setup
ssh myserver
cd /root/server-setup
chmod +x setup.sh deploy.sh modules/*.sh
./setup.sh
```

## 5. Update SSH Config (After Setup)

After `setup.sh` completes, root SSH login is disabled. Update your SSH config to use the deploy user:

```
Host myserver
    HostName YOUR_SERVER_IP
    User deploy
    IdentityFile ~/.ssh/myserver
```

The **same key** now works for the deploy user (setup copied it automatically).

Test the connection:

```bash
ssh myserver
```

## Summary

| Stage | SSH User | Purpose |
|-------|----------|---------|
| Initial setup | `root` | Run `setup.sh` to configure server |
| After setup | `deploy` | All access (use `sudo -i` for root shell) |

You use the same SSH key for both - just change the `User` in your SSH config after setup is complete.

## Security Notes

- Use a strong passphrase when generating keys
- Keep private keys secure and never share them
- Root login is disabled after running `setup.sh`
- Your key is automatically copied to the deploy user during setup
