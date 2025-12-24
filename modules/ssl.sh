#!/bin/bash
# Let's Encrypt / Certbot module
# Configures SSL certificates with automatic renewal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Install certbot
install_certbot() {
    log_step "Installing Certbot"
    
    # Install certbot and nginx plugin
    install_packages "certbot" "python3-certbot-nginx"
    
    log_success "Certbot installed"
}

# Obtain SSL certificate
obtain_certificate() {
    local domain="${DOMAIN:-}"
    local email="${ADMIN_EMAIL:-}"
    
    log_step "Obtaining SSL certificate for $domain"
    
    # Validate domain
    if [[ -z "$domain" ]]; then
        log_error "Domain is required for SSL certificate"
        exit 1
    fi
    
    # Validate email
    if [[ -z "$email" ]]; then
        log_error "Email is required for Let's Encrypt notifications"
        exit 1
    fi
    
    # Check if certificate already exists
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        log_info "Certificate for $domain already exists"
        if confirm "Do you want to renew/recreate it?"; then
            certbot_action="--force-renewal"
        else
            return 0
        fi
    else
        certbot_action=""
    fi
    
    # Make sure nginx is running
    if ! systemctl is-active --quiet nginx; then
        systemctl start nginx
    fi
    
    # Obtain certificate with nginx plugin
    log_info "Requesting certificate from Let's Encrypt..."
    
    if certbot --nginx \
        -d "$domain" \
        -d "www.$domain" \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        --redirect \
        --hsts \
        --staple-ocsp \
        $certbot_action; then
        log_success "SSL certificate obtained successfully"
    else
        log_error "Failed to obtain SSL certificate"
        log_info "Make sure your domain's DNS is pointing to this server"
        log_info "and that ports 80 and 443 are accessible from the internet"
        return 1
    fi
    
    save_state "SSL_CERTIFICATE" "$domain"
}

# Configure certificate auto-renewal
configure_renewal() {
    log_step "Configuring certificate auto-renewal"
    
    # Certbot installs a systemd timer by default
    # We'll verify it's enabled and add hooks
    
    # Enable the timer if not already
    systemctl enable certbot.timer
    systemctl start certbot.timer
    
    # Create renewal hooks
    local hooks_dir="/etc/letsencrypt/renewal-hooks"
    mkdir -p "$hooks_dir/deploy"
    
    # Create deploy hook to reload nginx
    cat > "$hooks_dir/deploy/reload-nginx.sh" << 'EOF'
#!/bin/bash
# Reload nginx after certificate renewal
systemctl reload nginx
EOF
    chmod +x "$hooks_dir/deploy/reload-nginx.sh"
    
    # Create pre-hook to check nginx config
    mkdir -p "$hooks_dir/pre"
    cat > "$hooks_dir/pre/check-nginx.sh" << 'EOF'
#!/bin/bash
# Verify nginx config before renewal
nginx -t || exit 1
EOF
    chmod +x "$hooks_dir/pre/check-nginx.sh"
    
    log_success "Auto-renewal configured"
    
    # Show timer status
    log_info "Certbot timer status:"
    systemctl status certbot.timer --no-pager || true
}

# Test renewal
test_renewal() {
    log_step "Testing certificate renewal"
    
    if certbot renew --dry-run; then
        log_success "Renewal test passed"
    else
        log_warning "Renewal test failed - check configuration"
    fi
}

# Update nginx config for SSL best practices
update_nginx_ssl() {
    local domain="${DOMAIN:-}"
    local nginx_conf="/etc/nginx/sites-available/$domain"
    
    log_step "Updating nginx SSL configuration"
    
    # Certbot already configures SSL, but we add extra security
    # This is done by including our ssl-params snippet
    
    if [[ -f "$nginx_conf" ]]; then
        # Add SSL params include if not present (only once, in the HTTPS server block)
        if ! grep -q "snippets/ssl-params.conf" "$nginx_conf"; then
            # Find the first ssl_certificate line and add include after it (only once)
            sed -i '0,/ssl_certificate/{/ssl_certificate/a\    include snippets/ssl-params.conf;
            }' "$nginx_conf" 2>/dev/null || true
        fi
        
        # Test and reload nginx
        if nginx -t; then
            systemctl reload nginx
            log_success "Nginx SSL configuration updated"
        else
            log_warning "Nginx config test failed after SSL update"
            # Remove the include we just added if it caused the failure
            sed -i '/include snippets\/ssl-params.conf;/d' "$nginx_conf" 2>/dev/null || true
            log_info "Reverted ssl-params include - using Certbot defaults"
        fi
    fi
}

# Show certificate info
show_certificate_info() {
    local domain="${DOMAIN:-}"
    
    log_step "Certificate information"
    echo ""
    
    if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
        certbot certificates -d "$domain" 2>/dev/null || true
    else
        log_info "No certificate found for $domain"
    fi
    
    echo ""
}

# Revoke certificate (for cleanup)
revoke_certificate() {
    local domain="${DOMAIN:-}"
    
    if [[ -z "$domain" ]]; then
        log_error "Domain is required"
        return 1
    fi
    
    if confirm "Are you sure you want to revoke the certificate for $domain?" "n"; then
        certbot revoke --cert-name "$domain" --delete-after-revoke
        log_success "Certificate revoked and deleted"
    fi
}

# Main function
setup_ssl() {
    check_root
    
    log_step "Starting SSL/TLS configuration"
    print_separator
    
    # Validate required variables
    if [[ -z "${DOMAIN:-}" ]]; then
        log_error "DOMAIN environment variable is required"
        exit 1
    fi
    
    if [[ -z "${ADMIN_EMAIL:-}" ]]; then
        log_error "ADMIN_EMAIL environment variable is required"
        exit 1
    fi
    
    install_certbot
    obtain_certificate
    update_nginx_ssl
    configure_renewal
    test_renewal
    show_certificate_info
    
    print_separator
    log_success "SSL/TLS configuration complete"
    log_info "Your site is now available at https://$DOMAIN"
    
    save_state "SSL_CONFIGURED" "$(date +%Y%m%d_%H%M%S)"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssl
fi
