#!/bin/bash
# Utility functions for server setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${GREEN}==>${NC} $1"
}

# Check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if running on Ubuntu
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS. /etc/os-release not found."
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is designed for Ubuntu. Detected: $ID"
        exit 1
    fi
    
    log_info "Detected Ubuntu $VERSION_ID"
}

# Backup a file before modifying
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Check if a package is installed
is_installed() {
    dpkg -l "$1" &> /dev/null
}

# Install packages if not already installed
install_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing packages: ${to_install[*]}"
        apt-get install -y "${to_install[@]}"
    else
        log_info "All required packages already installed"
    fi
}

# Validate domain name format
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Validate email format
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Validate IP address
validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    return 0
}

# Get server's public IP
get_public_ip() {
    curl -s https://ipinfo.io/ip 2>/dev/null || \
    curl -s https://api.ipify.org 2>/dev/null || \
    curl -s https://ifconfig.me 2>/dev/null
}

# Prompt for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -rp "$prompt" response
    response=${response:-$default}
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Generate random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d '/+=' | head -c "$length"
}

# Wait for a service to be ready
wait_for_service() {
    local service="$1"
    local max_attempts="${2:-30}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    return 1
}

# Check if port is in use
port_in_use() {
    local port="$1"
    ss -tuln | grep -q ":$port "
}

# Create directory with proper permissions
create_secure_dir() {
    local dir="$1"
    local owner="${2:-root}"
    local perms="${3:-755}"
    
    mkdir -p "$dir"
    chown "$owner:$owner" "$dir"
    chmod "$perms" "$dir"
}

# Add line to file if not exists
add_line_if_missing() {
    local file="$1"
    local line="$2"
    
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        return 0
    fi
    return 1
}

# Remove line from file
remove_line() {
    local file="$1"
    local pattern="$2"
    
    if [[ -f "$file" ]]; then
        sed -i "/$pattern/d" "$file"
    fi
}

# Check if reboot is required
reboot_required() {
    [[ -f /var/run/reboot-required ]]
}

# Print a separator line
print_separator() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Save installation state
save_state() {
    local state_file="/root/.server-setup-state"
    local key="$1"
    local value="$2"
    
    # Create file if not exists
    touch "$state_file"
    chmod 600 "$state_file"
    
    # Remove existing key if present
    sed -i "/^${key}=/d" "$state_file"
    
    # Add new value
    echo "${key}=${value}" >> "$state_file"
}

# Load installation state
load_state() {
    local state_file="/root/.server-setup-state"
    local key="$1"
    
    if [[ -f "$state_file" ]]; then
        grep "^${key}=" "$state_file" | cut -d'=' -f2
    fi
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_step
export -f check_root check_ubuntu backup_file
export -f is_installed install_packages
export -f validate_domain validate_email validate_ip get_public_ip
export -f confirm generate_password wait_for_service port_in_use
export -f create_secure_dir add_line_if_missing remove_line
export -f reboot_required print_separator save_state load_state
