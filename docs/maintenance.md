# Maintenance Guide

Common maintenance tasks for your server.

## Checking Service Status

```bash
# All services at once
systemctl status nginx fail2ban ufw

# Individual services
systemctl status nginx
systemctl status fail2ban
systemctl status certbot.timer
```

## Viewing Logs

```bash
# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log

# Fail2ban logs
tail -f /var/log/fail2ban.log

# System auth logs (SSH attempts)
tail -f /var/log/auth.log

# Unattended upgrades
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

## SSL Certificate Management

```bash
# View certificates and expiry dates
certbot certificates

# Test renewal (dry run)
certbot renew --dry-run

# Force renewal
certbot renew --force-renewal

# Add a new domain
certbot --nginx -d newdomain.com
```

## Firewall Management

```bash
# Check status and rules
ufw status verbose

# Allow a new port
ufw allow 8080/tcp

# Remove a rule
ufw delete allow 8080/tcp

# Check app profiles
ufw app list
```

## Fail2ban Management

```bash
# View jail status
fail2ban-client status
fail2ban-client status sshd

# Unban an IP address
fail2ban-client set sshd unbanip 192.168.1.100

# Ban an IP manually
fail2ban-client set sshd banip 192.168.1.100

# Reload configuration
fail2ban-client reload
```

## Nginx Management

```bash
# Test configuration
nginx -t

# Reload configuration (no downtime)
systemctl reload nginx

# Restart nginx
systemctl restart nginx

# View loaded configuration
nginx -T
```

## System Updates

```bash
# Manual update
apt update && apt upgrade -y

# Check what would be auto-updated
apt list --upgradable

# View pending automatic updates
cat /var/run/reboot-required 2>/dev/null && echo "Reboot required"
```

## Disk Usage

```bash
# Overall disk usage
df -h

# Web directory size
du -sh /var/www/html

# Find large files
find /var/log -type f -size +100M
```

## Backup Considerations

Important files to back up:

```
/etc/nginx/                 # Nginx configuration
/etc/fail2ban/              # Fail2ban configuration  
/etc/letsencrypt/           # SSL certificates
/var/www/html/              # Website content
~/.ssh/authorized_keys      # SSH keys
```

Example backup command:
```bash
tar -czvf backup-$(date +%Y%m%d).tar.gz \
    /etc/nginx \
    /etc/fail2ban \
    /etc/letsencrypt \
    /var/www/html
```

## Troubleshooting

### Site not loading

1. Check nginx status: `systemctl status nginx`
2. Test config: `nginx -t`
3. Check firewall: `ufw status`
4. View error log: `tail /var/log/nginx/error.log`

### SSH connection refused

1. Check if banned: `fail2ban-client status sshd`
2. Verify firewall: `ufw status`
3. Check SSH service: `systemctl status ssh`

### SSL certificate errors

1. Test renewal: `certbot renew --dry-run`
2. Check certificate: `certbot certificates`
3. Verify timer: `systemctl status certbot.timer`

### High memory/CPU usage

```bash
# View top processes
top -o %MEM
top -o %CPU

# Check nginx worker processes
ps aux | grep nginx
```
