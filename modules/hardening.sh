#!/bin/bash
# System hardening module
# Configures users, SSH, and kernel parameters

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Create deploy user for website management
setup_deploy_user() {
    local username="${DEPLOY_USER:-deploy}"
    
    log_step "Setting up deploy user: $username"
    
    if id "$username" &>/dev/null; then
        log_info "User $username already exists"
    else
        # Create user with home directory, no password login
        useradd -m -s /bin/bash "$username"
        log_success "Created user $username"
    fi
    
    # Set password for the deploy user (required for sudo)
    log_info "Set a password for the $username user (required for sudo access)"
    passwd "$username"
    
    # Add to www-data group for nginx
    usermod -aG www-data "$username"
    
    # Add to sudo group for full admin access
    usermod -aG sudo "$username"
    
    # Create .ssh directory
    local ssh_dir="/home/$username/.ssh"
    create_secure_dir "$ssh_dir" "$username" 700
    
    # Create authorized_keys file
    touch "$ssh_dir/authorized_keys"
    chown "$username:$username" "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    # If root has authorized_keys, copy them for the deploy user
    if [[ -f /root/.ssh/authorized_keys ]]; then
        if confirm "Copy root's SSH keys to $username?"; then
            cat /root/.ssh/authorized_keys >> "$ssh_dir/authorized_keys"
            log_success "Copied SSH keys to $username"
        fi
    fi
    
    # Allow deploy user to run nginx commands without password
    # Full sudo access is granted via sudo group membership
    local sudoers_file="/etc/sudoers.d/$username"
    cat > "$sudoers_file" << EOF
# Allow $username to manage nginx without password
$username ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
$username ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
$username ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
$username ALL=(ALL) NOPASSWD: /bin/systemctl status nginx
EOF
    chmod 440 "$sudoers_file"
    
    log_success "Deploy user configured"
    save_state "DEPLOY_USER" "$username"
}

# Harden SSH configuration
harden_ssh() {
    local ssh_port="${SSH_PORT:-22}"
    local sshd_config="/etc/ssh/sshd_config"
    
    log_step "Hardening SSH configuration"
    
    backup_file "$sshd_config"
    
    # Create a hardened sshd_config
    cat > "${sshd_config}.d/99-hardening.conf" << EOF
# Server Setup - SSH Hardening
# Generated on $(date)

# Port configuration
Port $ssh_port

# Protocol and authentication
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Key exchange and ciphers (modern and secure)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Login settings
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30

# Disable unused features
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
GatewayPorts no

# Keep connections alive
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
LogLevel VERBOSE

# Restrict users (uncomment and modify as needed)
# AllowUsers ${DEPLOY_USER:-deploy}
EOF

    # Ensure sshd_config.d is included
    if ! grep -q "Include /etc/ssh/sshd_config.d/\*.conf" "$sshd_config"; then
        echo "Include /etc/ssh/sshd_config.d/*.conf" >> "$sshd_config"
    fi
    
    # Test SSH configuration
    if sshd -t; then
        log_success "SSH configuration valid"
        systemctl reload ssh
    else
        log_error "SSH configuration invalid, restoring backup"
        rm -f "${sshd_config}.d/99-hardening.conf"
        exit 1
    fi
    
    if [[ "$ssh_port" != "22" ]]; then
        log_warning "SSH port changed to $ssh_port"
        log_warning "Make sure to update your firewall and connection settings!"
    fi
    
    save_state "SSH_PORT" "$ssh_port"
}

# Harden kernel parameters with sysctl
harden_sysctl() {
    local sysctl_file="/etc/sysctl.d/99-security.conf"
    
    log_step "Configuring kernel security parameters"
    
    cat > "$sysctl_file" << 'EOF'
# Server Setup - Kernel Hardening
# Network security

# Disable IP forwarding (not a router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable TCP SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6 if not needed (uncomment if desired)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# TCP hardening
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_syn_backlog = 4096

# Memory protection
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict kernel profiling
kernel.perf_event_paranoid = 3

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# Increase file descriptor limits
fs.file-max = 65535
fs.nr_open = 65535

# Connection tracking limits (for busy servers)
net.netfilter.nf_conntrack_max = 131072
EOF

    # Apply sysctl settings
    sysctl --system > /dev/null 2>&1
    
    log_success "Kernel parameters configured"
}

# Set timezone
configure_timezone() {
    local timezone="${TIMEZONE:-UTC}"
    
    log_step "Configuring timezone: $timezone"
    
    if timedatectl set-timezone "$timezone" 2>/dev/null; then
        log_success "Timezone set to $timezone"
    else
        log_warning "Could not set timezone to $timezone, keeping current setting"
    fi
    
    # Enable NTP sync
    timedatectl set-ntp true
    log_info "NTP synchronization enabled"
}

# Disable unused services
disable_unused_services() {
    log_step "Disabling unused services"
    
    local services_to_disable=(
        "cups"
        "cups-browsed"
        "avahi-daemon"
        "bluetooth"
        "ModemManager"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable --now "$service" 2>/dev/null || true
            log_info "Disabled $service"
        fi
    done
}

# Set secure file permissions
secure_permissions() {
    log_step "Setting secure file permissions"
    
    # Secure cron directories
    chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly 2>/dev/null || true
    
    # Secure SSH directory
    chmod 700 /root/.ssh 2>/dev/null || true
    chmod 600 /root/.ssh/* 2>/dev/null || true
    
    # Restrict access to sensitive files
    chmod 600 /etc/ssh/sshd_config
    chmod 640 /etc/shadow
    
    log_success "File permissions secured"
}

# Configure login settings
configure_login_settings() {
    log_step "Configuring login settings"
    
    # Set password policies
    local login_defs="/etc/login.defs"
    backup_file "$login_defs"
    
    # Update password aging
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$login_defs"
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' "$login_defs"
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' "$login_defs"
    
    # Configure login timeout
    local profile_file="/etc/profile.d/timeout.sh"
    cat > "$profile_file" << 'EOF'
# Auto logout after 15 minutes of inactivity
TMOUT=900
readonly TMOUT
export TMOUT
EOF
    
    log_success "Login settings configured"
}

# Main function
setup_hardening() {
    check_root
    
    log_step "Starting system hardening"
    print_separator
    
    # Update package lists
    apt-get update -qq
    
    # Install required packages
    install_packages "openssh-server" "sudo" "curl"
    
    # Run hardening steps
    configure_timezone
    setup_deploy_user
    harden_ssh
    harden_sysctl
    disable_unused_services
    secure_permissions
    configure_login_settings
    
    print_separator
    log_success "System hardening complete"
    
    save_state "HARDENING_COMPLETE" "$(date +%Y%m%d_%H%M%S)"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_hardening
fi
