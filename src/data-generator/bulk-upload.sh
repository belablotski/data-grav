#!/bin/bash

##############################################################################
# Data-Grav Bulk Upload Script
# Generates N files of specified size, uploads to Azure, and cleans up locally
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
NUM_FILES=${NUM_FILES:-100}
FILE_SIZE=${FILE_SIZE:-1GB}
PATTERN=${PATTERN:-"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"}
CONTAINER=${CONTAINER:-data-grav}
PREFIX=${PREFIX:-test-data}
TEMP_DIR=${TEMP_DIR:-./temp}
KEEP_LOCAL=${KEEP_LOCAL:-false}

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##############################################################################
# Functions
##############################################################################

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

format_duration() {
    local seconds=$1
    if [ $seconds -lt 60 ]; then
        echo "${seconds}s"
    elif [ $seconds -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m $((seconds % 60))s"
    fi
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if node is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    print_success "Node.js: $(node --version)"
    
    # Check if az cli is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI installed"
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Run: az login"
        exit 1
    fi
    print_success "Azure authentication verified"
    
    # Check if generate.js exists
    if [ ! -f "$SCRIPT_DIR/generate.js" ]; then
        print_error "generate.js not found in $SCRIPT_DIR"
        exit 1
    fi
    print_success "Data generator found"
    
    # Check if deployment outputs exist
    if [ ! -f "$SCRIPT_DIR/../../infra/deployment-outputs.env" ]; then
        print_warning "Deployment outputs not found. Using default storage account name."
        if [ -z "$AZURE_STORAGE_ACCOUNT" ]; then
            print_error "AZURE_STORAGE_ACCOUNT environment variable not set"
            exit 1
        fi
    else
        source "$SCRIPT_DIR/../../infra/deployment-outputs.env"
        print_success "Deployment outputs loaded"
    fi
    
    echo ""
}

print_configuration() {
    print_header "Configuration"
    echo -e "  Number of Files:    ${YELLOW}${NUM_FILES}${NC}"
    echo -e "  File Size:          ${YELLOW}${FILE_SIZE}${NC}"
    echo -e "  Pattern:            ${YELLOW}${PATTERN}${NC}"
    echo -e "  Storage Account:    ${YELLOW}${AZURE_STORAGE_ACCOUNT}${NC}"
    echo -e "  Container:          ${YELLOW}${CONTAINER}${NC}"
    echo -e "  File Prefix:        ${YELLOW}${PREFIX}${NC}"
    echo -e "  Temp Directory:     ${YELLOW}${TEMP_DIR}${NC}"
    echo -e "  Keep Local Files:   ${YELLOW}${KEEP_LOCAL}${NC}"
    echo ""
}

confirm_execution() {
    echo -e "${YELLOW}This will generate and upload ${NUM_FILES} files of ${FILE_SIZE} each.${NC}"
    echo -e "${YELLOW}This may take considerable time and storage.${NC}"
    echo ""
    read -p "Continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Operation cancelled by user"
        exit 0
    fi
}

create_temp_directory() {
    if [ ! -d "$TEMP_DIR" ]; then
        mkdir -p "$TEMP_DIR"
        print_success "Created temp directory: $TEMP_DIR"
    fi
}

cleanup_temp_directory() {
    if [ "$KEEP_LOCAL" = "false" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_success "Cleaned up temp directory"
    fi
}

process_file() {
    local file_num=$1
    local file_start=$(date +%s)
    
    echo ""
    print_header "Processing File $file_num/$NUM_FILES"
    
    # Generate
    local filename="${PREFIX}-$(printf "%04d" $file_num).txt"
    local filepath="$TEMP_DIR/$filename"
    
    print_info "Generating: $filename"
    node "$SCRIPT_DIR/generate.js" \
        --type text \
        --size "$FILE_SIZE" \
        --output "$filepath" \
        --pattern "$PATTERN" > /dev/null 2>&1
    
    if [ ! -f "$filepath" ]; then
        print_error "Failed to generate file: $filepath"
        return 1
    fi
    
    local filesize=$(du -h "$filepath" | cut -f1)
    print_success "Generated: $filename ($filesize)"
    
    # Upload
    print_info "Uploading: $filename"
    local upload_start=$(date +%s)
    
    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --name "$filename" \
        --file "$filepath" \
        --auth-mode key \
        --output none 2>/dev/null
    
    local upload_end=$(date +%s)
    local upload_duration=$((upload_end - upload_start))
    print_success "Uploaded in $(format_duration $upload_duration)"
    
    # Clean up
    if [ "$KEEP_LOCAL" = "false" ]; then
        rm -f "$filepath"
        print_success "Deleted local file: $filename"
    fi
    
    local file_end=$(date +%s)
    local file_duration=$((file_end - file_start))
    
    print_success "File $file_num complete in $(format_duration $file_duration)"
    
    return 0
}

print_statistics() {
    local total_duration=$1
    local avg_duration=$2
    
    echo ""
    print_header "Statistics"
    echo -e "  Total Files:        ${GREEN}${NUM_FILES}${NC}"
    echo -e "  Total Duration:     ${GREEN}$(format_duration $total_duration)${NC}"
    echo -e "  Average per File:   ${GREEN}$(format_duration $avg_duration)${NC}"
    echo -e "  Storage Account:    ${GREEN}${AZURE_STORAGE_ACCOUNT}${NC}"
    echo -e "  Container:          ${GREEN}${CONTAINER}${NC}"
    echo ""
}

verify_uploads() {
    print_header "Verifying Uploads"
    print_info "Listing uploaded files in container: $CONTAINER"
    echo ""
    
    az storage blob list \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --prefix "$PREFIX" \
        --auth-mode key \
        --query "[].{Name:name, Size:properties.contentLength, Created:properties.creationTime}" \
        --output table 2>/dev/null
}

##############################################################################
# Main Script
##############################################################################

main() {
    local script_start=$(date +%s)
    
    print_header "Data-Grav Bulk Upload"
    echo ""
    
    # Prerequisites
    check_prerequisites
    
    # Configuration
    print_configuration
    
    # Confirmation
    confirm_execution
    
    # Setup
    create_temp_directory
    
    # Process files
    print_header "Processing Files"
    local success_count=0
    local failed_count=0
    
    for ((i=1; i<=NUM_FILES; i++)); do
        if process_file $i; then
            success_count=$((success_count + 1))
        else
            print_error "Failed to process file $i"
            failed_count=$((failed_count + 1))
        fi
        
        # Brief pause between files to avoid rate limiting
        sleep 1
    done
    
    # Cleanup
    cleanup_temp_directory
    
    # Statistics
    local script_end=$(date +%s)
    local total_duration=$((script_end - script_start))
    local avg_duration=0
    if [ $success_count -gt 0 ]; then
        avg_duration=$((total_duration / success_count))
    fi
    
    print_statistics $total_duration $avg_duration
    
    # Verify
    verify_uploads
    
    # Final summary
    echo ""
    print_header "Summary"
    print_success "Successfully processed: $success_count files"
    if [ $failed_count -gt 0 ]; then
        print_error "Failed: $failed_count files"
    fi
    echo ""
    print_success "Bulk upload complete!"
}

# Trap for cleanup on exit
trap cleanup_temp_directory EXIT

# Run main function
main
