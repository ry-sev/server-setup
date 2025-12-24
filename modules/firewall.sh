#!/bin/bash
# UFW Firewall module
# Configures firewall rules for a secure web server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Install and configure UFW
setup_ufw() {
    local ssh_port="${SSH_PORT:-22}"
    
    log_step "Setting up UFW firewall"
    
    # Install UFW
    install_packages "ufw"
    
    # Reset UFW to defaults (in case of previous configuration)
    log_info "Resetting UFW to defaults"
    ufw --force reset > /dev/null
    
    # Set default policies
    log_info "Setting default policies"
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (critical - do this first!)
    log_info "Allowing SSH on port $ssh_port"
    ufw allow "$ssh_port/tcp" comment 'SSH'
    
    # Allow HTTP and HTTPS
    log_info "Allowing HTTP (80) and HTTPS (443)"
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Rate limit SSH connections
    log_info "Enabling rate limiting on SSH"
    ufw limit "$ssh_port/tcp" comment 'SSH rate limit'
    
    # Enable logging
    ufw logging on
    ufw logging low  # Options: off, low, medium, high, full
    
    # Enable UFW
    log_info "Enabling UFW"
    ufw --force enable
    
    log_success "UFW firewall configured and enabled"
    
    # Show status
    echo ""
    ufw status verbose
    echo ""
    
    save_state "UFW_CONFIGURED" "$(date +%Y%m%d_%H%M%S)"
}

# Add custom rules
add_custom_rules() {
    log_step "Checking for custom firewall rules"
    
    local custom_rules="/root/.server-setup-ufw-rules"
    
    if [[ -f "$custom_rules" ]]; then
        log_info "Applying custom rules from $custom_rules"
        while IFS= read -r rule; do
            [[ -z "$rule" || "$rule" =~ ^# ]] && continue
            log_info "Adding rule: $rule"
            ufw $rule
        done < "$custom_rules"
    fi
}

# Configure IPv6
configure_ipv6() {
    local ufw_default="/etc/default/ufw"
    
    log_step "Configuring IPv6 support"
    
    if [[ -f "$ufw_default" ]]; then
        # Enable IPv6 in UFW
        sed -i 's/^IPV6=.*/IPV6=yes/' "$ufw_default"
        log_success "IPv6 support enabled in UFW"
    fi
}

# Block common attack ports
block_attack_ports() {
    log_step "Blocking common attack ports"
    
    # These ports are commonly targeted but shouldn't be accessible
    local block_ports=(
        "23"    # Telnet
        "25"    # SMTP (if not mail server)
        "135"   # Windows RPC
        "137"   # NetBIOS
        "138"   # NetBIOS
        "139"   # NetBIOS
        "445"   # SMB
        "3389"  # RDP
    )
    
    for port in "${block_ports[@]}"; do
        ufw deny "$port" comment 'Block common attack port' 2>/dev/null || true
    done
    
    log_success "Common attack ports blocked"
}

# Set up rate limiting for web traffic
setup_rate_limiting() {
    log_step "Configuring connection rate limiting"
    
    # UFW doesn't support complex rate limiting
    # We'll use iptables directly for this
    local rules_file="/etc/ufw/before.rules"
    
    backup_file "$rules_file"
    
    # Check if rate limiting rules already exist
    if grep -q "RATE_LIMIT" "$rules_file"; then
        log_info "Rate limiting rules already configured"
        return
    fi
    
    # Insert rate limiting rules before the final COMMIT
    # This limits new connections to 25 per 5 seconds per IP
    local rate_rules='
# Rate limiting for HTTP/HTTPS (insert before COMMIT)
-A ufw-before-input -p tcp --dport 80 -m state --state NEW -m recent --set --name HTTP_RATE_LIMIT
-A ufw-before-input -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 5 --hitcount 25 --name HTTP_RATE_LIMIT -j DROP
-A ufw-before-input -p tcp --dport 443 -m state --state NEW -m recent --set --name HTTPS_RATE_LIMIT
-A ufw-before-input -p tcp --dport 443 -m state --state NEW -m recent --update --seconds 5 --hitcount 25 --name HTTPS_RATE_LIMIT -j DROP
'
    
    # Insert before the COMMIT line
    sed -i "/^COMMIT$/i\\
# BEGIN RATE_LIMIT\\
$rate_rules\\
# END RATE_LIMIT" "$rules_file"
    
    log_success "Connection rate limiting configured"
}

# Show firewall status
show_status() {
    log_step "Current firewall status"
    echo ""
    ufw status numbered
    echo ""
}

# Main function
setup_firewall() {
    check_root
    
    log_step "Starting firewall configuration"
    print_separator
    
    setup_ufw
    configure_ipv6
    block_attack_ports
    add_custom_rules
    
    # Reload UFW to apply all changes
    ufw reload
    
    show_status
    
    print_separator
    log_success "Firewall configuration complete"
    
    log_warning "IMPORTANT: Make sure you can still SSH to the server before closing this session!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_firewall
fi
