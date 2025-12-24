#!/bin/bash
# Deployment script for Eleventy static sites
# Run this on your local machine or set up as a deployment hook

set -euo pipefail

# Configuration
REMOTE_USER="${DEPLOY_USER:-deploy}"
REMOTE_HOST="${SERVER_IP:-}"
REMOTE_PATH="${SITE_ROOT:-/var/www}/${DOMAIN:-example.com}/html"
LOCAL_BUILD_DIR="${LOCAL_BUILD_DIR:-./_site}"
SSH_PORT="${SSH_PORT:-22}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy an Eleventy static site to your server.

Options:
    -h, --host HOST       Server hostname or IP (required)
    -d, --domain DOMAIN   Domain name (required)
    -u, --user USER       SSH user (default: deploy)
    -p, --port PORT       SSH port (default: 22)
    -s, --source DIR      Local build directory (default: ./_site)
    -n, --dry-run         Show what would be done without doing it
    --help                Show this help message

Examples:
    $0 -h 192.168.1.100 -d example.com
    $0 -h myserver.com -d example.com -s ./dist
    $0 -h myserver.com -d example.com --dry-run

EOF
}

# Parse command line arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            REMOTE_PATH="/var/www/$DOMAIN/html"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -s|--source)
            LOCAL_BUILD_DIR="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REMOTE_HOST" ]]; then
    log_error "Server host is required (-h or --host)"
    usage
    exit 1
fi

if [[ -z "${DOMAIN:-}" ]]; then
    log_error "Domain is required (-d or --domain)"
    usage
    exit 1
fi

# Check if local build directory exists
if [[ ! -d "$LOCAL_BUILD_DIR" ]]; then
    log_error "Build directory not found: $LOCAL_BUILD_DIR"
    log_info "Run 'npx @11ty/eleventy' first to build your site"
    exit 1
fi

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    log_error "rsync is required but not installed"
    exit 1
fi

# Build rsync command
RSYNC_OPTS=(
    -avz
    --delete
    --checksum
    --exclude='.git'
    --exclude='.gitignore'
    --exclude='node_modules'
    --exclude='.DS_Store'
    --exclude='*.log'
    --exclude='.env*'
    --exclude='*.env'
    -e "ssh -p $SSH_PORT -o StrictHostKeyChecking=accept-new"
)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_OPTS+=(--dry-run)
    log_warning "DRY RUN MODE - No changes will be made"
fi

log_info "Deploying to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
log_info "Source: $LOCAL_BUILD_DIR"

# Count files
FILE_COUNT=$(find "$LOCAL_BUILD_DIR" -type f | wc -l)
log_info "Files to deploy: $FILE_COUNT"

# Run deployment
echo ""
if rsync "${RSYNC_OPTS[@]}" "$LOCAL_BUILD_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_success "Dry run completed - no changes made"
    else
        log_success "Deployment completed successfully!"
        log_info "Site available at: https://$DOMAIN"
    fi
else
    log_error "Deployment failed"
    exit 1
fi
