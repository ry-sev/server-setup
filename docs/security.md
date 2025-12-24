# Security Hardening Reference

This document explains the security measures applied by the setup scripts.

## SSH Hardening

**File:** `/etc/ssh/sshd_config.d/99-hardening.conf`

| Setting | Value | Purpose |
|---------|-------|---------|
| `PasswordAuthentication` | no | Prevents brute-force password attacks |
| `PermitRootLogin` | no | Disables root SSH login (use deploy user, then `sudo -i`) |
| `MaxAuthTries` | 3 | Limits login attempts per connection |
| `LoginGraceTime` | 30 | Reduces window for attacks |
| `X11Forwarding` | no | Disables unnecessary feature |
| `AllowAgentForwarding` | no | Prevents agent hijacking |
| `ClientAliveInterval` | 300 | Disconnects idle sessions |

## Firewall (UFW)

Default policy: **deny incoming, allow outgoing**

Open ports:
- **22/tcp** - SSH
- **80/tcp** - HTTP (redirects to HTTPS)
- **443/tcp** - HTTPS

## Fail2ban

Protects against brute-force attacks:

| Jail | Action |
|------|--------|
| `sshd` | Bans IPs after 3 failed SSH attempts |
| `nginx-http-auth` | Bans IPs after failed HTTP auth |
| `nginx-botsearch` | Bans vulnerability scanners |
| `nginx-limit-req` | Bans IPs exceeding rate limits |

Default ban time: 1 hour

View banned IPs:
```bash
fail2ban-client status sshd
```

Unban an IP:
```bash
fail2ban-client set sshd unbanip 1.2.3.4
```

## Kernel Hardening (sysctl)

**File:** `/etc/sysctl.d/99-security.conf`

| Setting | Purpose |
|---------|---------|
| `net.ipv4.tcp_syncookies` | SYN flood protection |
| `net.ipv4.conf.all.rp_filter` | Prevents IP spoofing |
| `net.ipv4.conf.all.accept_redirects` | Blocks ICMP redirects |
| `net.ipv4.conf.all.log_martians` | Logs suspicious packets |
| `kernel.randomize_va_space` | ASLR enabled |

## Nginx Security Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | SAMEORIGIN | Prevents clickjacking |
| `X-Content-Type-Options` | nosniff | Prevents MIME sniffing |
| `X-XSS-Protection` | 1; mode=block | XSS filter |
| `Referrer-Policy` | strict-origin-when-cross-origin | Controls referrer info |
| `Content-Security-Policy` | default-src 'self'... | Controls resource loading |
| `Strict-Transport-Security` | max-age=31536000 | Forces HTTPS |

## Automatic Updates

Unattended-upgrades handles security patches automatically:

- **What updates:** Security updates only
- **When:** Daily
- **Auto-reboot:** Enabled at 3:00 AM if required
- **Cleanup:** Old packages auto-removed

Check status:
```bash
systemctl status unattended-upgrades
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

## SSL/TLS Configuration

- **Protocols:** TLS 1.2, TLS 1.3 only
- **Ciphers:** Modern, secure cipher suites
- **OCSP Stapling:** Enabled
- **Auto-renewal:** Certbot timer runs twice daily

Test your SSL configuration:
```bash
# Check certificate expiry
certbot certificates

# Force renewal test
certbot renew --dry-run
```
