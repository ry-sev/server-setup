#!/bin/bash
#
# Ubuntu Server Setup Script
# Configures a fresh Ubuntu server for secure static site hosting
#
# Usage: ./setup.sh
#
# This script will:
# - Harden system security (SSH, sysctl, users)
# - Configure UFW firewall
# - Set up fail2ban intrusion prevention
# - Install and configure nginx for static sites
# - Obtain SSL certificate from Let's Encrypt
# - Enable automatic security updates
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# Source utilities
source "$MODULES_DIR/utils.sh"

# Banner
show_banner() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "         Ubuntu Server Setup for Static Site Hosting        "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Collect user configuration
collect_config() {
    log_step "Configuration"
    echo ""
    
    # Domain
    while true; do
        read -rp "Enter your domain name (e.g., example.com): " input_domain
        if validate_domain "$input_domain"; then
            export DOMAIN="$input_domain"
            break
        else
            log_error "Invalid domain format. Please try again."
        fi
    done
    
    # Email
    while true; do
        read -rp "Enter admin email (for SSL and notifications): " input_email
        if validate_email "$input_email"; then
            export ADMIN_EMAIL="$input_email"
            break
        else
            log_error "Invalid email format. Please try again."
        fi
    done
    
    # Server IP (auto-detect or manual)
    local detected_ip
    detected_ip=$(get_public_ip)
    
    if [[ -n "$detected_ip" ]]; then
        log_info "Detected public IP: $detected_ip"
        if confirm "Use this IP address?" "y"; then
            export SERVER_IP="$detected_ip"
        else
            read -rp "Enter server IP address: " SERVER_IP
            export SERVER_IP
        fi
    else
        read -rp "Enter server IP address: " SERVER_IP
        export SERVER_IP
    fi
    
    # SSH Port
    read -rp "SSH port [22]: " input_ssh_port
    export SSH_PORT="${input_ssh_port:-22}"
    
    # Deploy user
    read -rp "Deploy username [deploy]: " input_deploy_user
    export DEPLOY_USER="${input_deploy_user:-deploy}"
    
    # Timezone
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    read -rp "Timezone [$current_tz]: " input_timezone
    export TIMEZONE="${input_timezone:-$current_tz}"
    
    # Web root
    export WEB_ROOT="/var/www"
    
    echo ""
    print_separator
    log_info "Configuration Summary:"
    echo "  Domain:       $DOMAIN"
    echo "  Email:        $ADMIN_EMAIL"
    echo "  Server IP:    $SERVER_IP"
    echo "  SSH Port:     $SSH_PORT"
    echo "  Deploy User:  $DEPLOY_USER"
    echo "  Timezone:     $TIMEZONE"
    echo "  Web Root:     $WEB_ROOT/$DOMAIN"
    print_separator
    echo ""
    
    if ! confirm "Proceed with this configuration?" "y"; then
        log_info "Setup cancelled"
        exit 0
    fi
}

# Load config from file if exists
load_config_file() {
    local config_file="$SCRIPT_DIR/config.env"
    
    if [[ -f "$config_file" ]]; then
        log_info "Found config.env file"
        if confirm "Load configuration from config.env?" "y"; then
            # shellcheck source=/dev/null
            source "$config_file"
            export DOMAIN ADMIN_EMAIL SERVER_IP SSH_PORT DEPLOY_USER TIMEZONE WEB_ROOT
            return 0
        fi
    fi
    return 1
}

# Pre-flight checks
preflight_checks() {
    log_step "Running pre-flight checks"
    
    check_root
    check_ubuntu
    
    # Check internet connectivity
    if ! ping -c 1 1.1.1.1 &> /dev/null; then
        log_error "No internet connectivity"
        exit 1
    fi
    log_info "Internet connectivity: OK"
    
    # Check DNS resolution
    if ! host google.com &> /dev/null; then
        log_warning "DNS resolution may be slow"
    fi
    
    # Check disk space (need at least 1GB free)
    local free_space
    free_space=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
    if [[ "$free_space" -lt 1 ]]; then
        log_error "Insufficient disk space (need at least 1GB)"
        exit 1
    fi
    log_info "Disk space: ${free_space}GB available"
    
    log_success "Pre-flight checks passed"
}

# Update system
update_system() {
    log_step "Updating system packages"
    
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    log_success "System updated"
}

# Install base packages
install_base_packages() {
    log_step "Installing base packages"
    
    install_packages \
        "curl" \
        "wget" \
        "git" \
        "vim" \
        "htop" \
        "ncdu" \
        "tree" \
        "jq" \
        "rsync" \
        "net-tools" \
        "dnsutils" \
        "software-properties-common" \
        "apt-transport-https" \
        "ca-certificates" \
        "gnupg" \
        "lsb-release"
    
    log_success "Base packages installed"
}

# Run all modules
run_modules() {
    # System hardening
    log_step "Running system hardening module"
    source "$MODULES_DIR/hardening.sh"
    setup_hardening
    
    # Firewall
    log_step "Running firewall module"
    source "$MODULES_DIR/firewall.sh"
    setup_firewall
    
    # Fail2ban
    log_step "Running fail2ban module"
    source "$MODULES_DIR/fail2ban.sh"
    setup_fail2ban
    
    # Nginx
    log_step "Running nginx module"
    source "$MODULES_DIR/nginx.sh"
    setup_nginx
    
    # SSL (Let's Encrypt)
    log_step "Running SSL module"
    echo ""
    log_warning "SSL certificate requires your domain's DNS to point to this server"
    log_info "Domain: $DOMAIN -> $SERVER_IP"
    echo ""
    
    if confirm "Is your DNS already configured and propagated?" "y"; then
        source "$MODULES_DIR/ssl.sh"
        setup_ssl
    else
        log_warning "Skipping SSL setup"
        log_info "Run 'modules/ssl.sh' later when DNS is ready"
    fi
    
    # Unattended upgrades
    log_step "Running unattended-upgrades module"
    source "$MODULES_DIR/updates.sh"
    setup_unattended_upgrades
}

# Show completion summary
show_summary() {
    echo ""
    print_separator
    echo ""
    log_success "Server setup complete!"
    echo ""
    echo "Configuration:"
    echo "  Domain:      https://$DOMAIN"
    echo "  Web Root:    $WEB_ROOT/$DOMAIN/html"
    echo "  Deploy User: $DEPLOY_USER"
    echo "  SSH Port:    $SSH_PORT"
    echo ""
    echo "Next steps:"
    echo "  1. Test SSH access: ssh -p $SSH_PORT $DEPLOY_USER@$SERVER_IP"
    echo "  2. Add your SSH key to /home/$DEPLOY_USER/.ssh/authorized_keys"
    echo "  3. Deploy your Eleventy site using deploy.sh"
    echo ""
    echo "Deployment example:"
    echo "  ./deploy.sh -h $SERVER_IP -d $DOMAIN -s ./_site"
    echo ""
    
    if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        echo "SSL Setup (when DNS is ready):"
        echo "  export DOMAIN=$DOMAIN"
        echo "  export ADMIN_EMAIL=$ADMIN_EMAIL"
        echo "  sudo ./modules/ssl.sh"
        echo ""
    fi
    
    echo "Useful commands:"
    echo "  nginx -t && systemctl reload nginx  # Reload nginx"
    echo "  fail2ban-client status              # Check fail2ban"
    echo "  ufw status                          # Check firewall"
    echo "  certbot certificates                # Check SSL certs"
    echo ""
    print_separator
    
    if reboot_required; then
        echo ""
        log_warning "A system reboot is required to complete the setup"
        if confirm "Reboot now?" "n"; then
            reboot
        fi
    fi
}

# Main function
main() {
    show_banner
    
    # Check if running as root
    check_root
    
    # Load config or collect interactively
    if ! load_config_file; then
        collect_config
    fi
    
    # Save config for reference
    cat > "$SCRIPT_DIR/config.env" << EOF
# Server Configuration (auto-generated)
# $(date)

DOMAIN="$DOMAIN"
ADMIN_EMAIL="$ADMIN_EMAIL"
SERVER_IP="$SERVER_IP"
SSH_PORT="$SSH_PORT"
DEPLOY_USER="$DEPLOY_USER"
TIMEZONE="$TIMEZONE"
WEB_ROOT="$WEB_ROOT"
EOF
    chmod 600 "$SCRIPT_DIR/config.env"
    
    # Run setup
    preflight_checks
    update_system
    install_base_packages
    run_modules
    show_summary
}

# Run main function
main "$@"
