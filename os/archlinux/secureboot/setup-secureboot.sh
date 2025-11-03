#!/bin/bash
#
# Secure Boot Setup Script for Arch Linux + Windows Dual Boot
#
# This script configures Secure Boot keys using sbctl to enable
# dual-booting with Windows while maintaining Secure Boot enabled.
#
# Author: Andres
# Last Updated: 2025

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root (use sudo)"
   exit 1
fi

echo_info "=== Secure Boot Setup for Dual Boot with Windows ==="
echo ""

# Step 1: Check if sbctl is installed
echo_info "Step 1: Checking if sbctl is installed..."
if ! command -v sbctl &> /dev/null; then
    echo_error "sbctl is not installed!"
    echo_info "Installing sbctl..."
    pacman -S --noconfirm sbctl
else
    echo_success "sbctl is already installed"
fi
echo ""

# Step 2: Check current Secure Boot status
echo_info "Step 2: Checking Secure Boot status..."
sbctl status
echo ""

# Step 3: Create keys if they don't exist
echo_info "Step 3: Creating Secure Boot keys..."
if sbctl create-keys 2>&1 | grep -q "already been created"; then
    echo_success "Keys already exist"
else
    echo_success "Keys created successfully"
fi
echo ""

# Step 4: Sign bootloader and kernel
echo_info "Step 4: Signing bootloader and kernel files..."

# Sign systemd-boot
if [ -f /efi/EFI/systemd/systemd-bootx64.efi ]; then
    sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi || echo_warning "Already signed or failed"
fi

# Sign fallback bootloader
if [ -f /efi/EFI/BOOT/BOOTX64.EFI ]; then
    sbctl sign -s /efi/EFI/BOOT/BOOTX64.EFI || echo_warning "Already signed or failed"
fi

# Find and sign all Linux kernels
echo_info "Finding and signing Linux kernels..."
find /efi -name "linux" -type f 2>/dev/null | while read -r kernel; do
    echo_info "Signing: $kernel"
    sbctl sign -s "$kernel" || echo_warning "Already signed or failed: $kernel"
done

echo_success "Signing completed"
echo ""

# Step 5: Verify signed files
echo_info "Step 5: Verifying signed files..."
sbctl verify | grep -E "(✓|linux|systemd|BOOT)" || true
echo ""

# Step 6: List currently enrolled keys
echo_info "Step 6: Current enrolled keys in firmware:"
sbctl list-enrolled-keys
echo ""

# Step 7: Enroll keys with Microsoft keys
echo_warning "=== IMPORTANT: Key Enrollment ==="
echo ""
echo_warning "You are about to enroll Secure Boot keys."
echo_warning "This will:"
echo_warning "  - Include Microsoft keys (so Windows can boot)"
echo_warning "  - Include your custom Linux signing keys"
echo_warning "  - Enable Secure Boot validation"
echo ""
echo_warning "After enrolling, you MUST:"
echo_warning "  1. Reboot your system"
echo_warning "  2. Enter BIOS/UEFI settings"
echo_warning "  3. Enable Secure Boot"
echo ""
echo_warning "If something goes wrong, you can:"
echo_warning "  - Enter BIOS and disable Secure Boot"
echo_warning "  - Use 'sbctl reset' to clear keys"
echo ""

read -p "Do you want to enroll keys now? (yes/no): " -r
echo ""
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo_info "Enrolling keys with Microsoft keys included..."

    # Enroll with Microsoft keys to maintain Windows compatibility
    if sbctl enroll-keys --microsoft; then
        echo_success "Keys enrolled successfully!"
        echo ""
        echo_success "=== Next Steps ==="
        echo_info "1. Reboot your system: 'reboot'"
        echo_info "2. Press DEL/F2/F12 (depends on motherboard) to enter BIOS"
        echo_info "3. Navigate to Boot -> Secure Boot settings"
        echo_info "4. Enable Secure Boot"
        echo_info "5. Save and Exit"
        echo_info "6. Both Linux and Windows should boot with Secure Boot enabled"
        echo ""
    else
        echo_error "Failed to enroll keys!"
        echo_info "You may need to:"
        echo_info "  - Enter BIOS and enable Setup Mode"
        echo_info "  - Clear existing keys in BIOS"
        echo_info "  - Try again"
        exit 1
    fi
else
    echo_warning "Key enrollment skipped."
    echo_info "You can enroll keys later with: sudo sbctl enroll-keys --microsoft"
fi

echo ""
echo_success "=== Setup Complete ==="
echo_info "Summary of what was done:"
echo_info "  ✓ sbctl installed/verified"
echo_info "  ✓ Secure Boot keys created"
echo_info "  ✓ Bootloader and kernels signed"
echo_info "  ✓ Microsoft keys prepared for enrollment"
echo ""
echo_info "Configuration files location:"
echo_info "  Keys: /var/lib/sbctl/keys/"
echo_info "  EFI:  /efi/"
echo ""
