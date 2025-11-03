#!/bin/bash
#
# Secure Boot Status Check Script
#
# This script displays the current status of Secure Boot configuration
# including signing status, enrolled keys, and boot configuration.
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║        SECURE BOOT STATUS CHECK                            ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if sbctl is installed
if ! command -v sbctl &> /dev/null; then
    echo -e "${RED}✗ sbctl is not installed!${NC}"
    echo -e "${YELLOW}Install with: sudo pacman -S sbctl${NC}"
    exit 1
fi

# 1. UEFI and Secure Boot Status
echo -e "${BOLD}${BLUE}1. UEFI & Secure Boot Status${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
sudo sbctl status
echo ""

# 2. Boot Configuration
echo -e "${BOLD}${BLUE}2. Boot Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
if command -v bootctl &> /dev/null; then
    bootctl status 2>/dev/null | grep -E "(Firmware:|Secure Boot:|Current Boot Loader:|Product:)" || echo "Unable to get bootctl status"
else
    echo "bootctl not available"
fi
echo ""

# 3. Enrolled Keys in Firmware
echo -e "${BOLD}${BLUE}3. Keys Enrolled in Firmware${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
sudo sbctl list-enrolled-keys
echo ""

# 4. Signed Files Status
echo -e "${BOLD}${BLUE}4. Signed Files Status${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Successfully Signed:${NC}"
sudo sbctl verify 2>/dev/null | grep "✓" | grep -v "does not exist"
echo ""
echo -e "${RED}✗ Not Signed (or errors):${NC}"
sudo sbctl verify 2>/dev/null | grep "✗" | head -5
if [ $(sudo sbctl verify 2>/dev/null | grep "✗" | wc -l) -gt 5 ]; then
    echo -e "${YELLOW}... and more (showing first 5)${NC}"
fi
echo ""

# 5. Key Files Location
echo -e "${BOLD}${BLUE}5. Signing Keys Location${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
if [ -d /var/lib/sbctl/keys ]; then
    echo -e "${GREEN}✓ Keys exist at: /var/lib/sbctl/keys/${NC}"
    ls -lh /var/lib/sbctl/keys/*/
else
    echo -e "${RED}✗ No keys found at /var/lib/sbctl/keys/${NC}"
    echo -e "${YELLOW}Run: sudo sbctl create-keys${NC}"
fi
echo ""

# 6. Pacman Hook Status
echo -e "${BOLD}${BLUE}6. Automatic Signing Hook${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
if [ -f /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook ]; then
    echo -e "${GREEN}✓ Pacman hook installed${NC}"
    echo -e "  Location: /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook"
else
    echo -e "${YELLOW}⚠ Pacman hook NOT installed${NC}"
    echo -e "  Kernels will need manual signing after updates"
fi
echo ""

# 7. Next Steps Recommendation
echo -e "${BOLD}${BLUE}7. Recommended Next Steps${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

SECURE_BOOT_ENABLED=$(sudo sbctl status | grep "Secure Boot:" | grep -o "Enabled" || echo "Disabled")

if [ "$SECURE_BOOT_ENABLED" = "Disabled" ]; then
    echo -e "${YELLOW}Secure Boot is currently DISABLED${NC}"
    echo ""

    # Check if keys are created
    if [ ! -d /var/lib/sbctl/keys/db ]; then
        echo -e "  ${YELLOW}→${NC} Create keys: ${CYAN}sudo sbctl create-keys${NC}"
    fi

    # Check if files are signed
    UNSIGNED_COUNT=$(sudo sbctl verify 2>/dev/null | grep -E "(systemd-boot|BOOT.*EFI|/linux$)" | grep "✗" | wc -l)
    if [ $UNSIGNED_COUNT -gt 0 ]; then
        echo -e "  ${YELLOW}→${NC} Sign files: ${CYAN}sudo sbctl sign-all${NC}"
    fi

    # Check if keys are enrolled
    CUSTOM_KEYS=$(sudo sbctl list-enrolled-keys | grep -i "sbctl\|custom" | wc -l)
    if [ $CUSTOM_KEYS -eq 0 ]; then
        echo -e "  ${YELLOW}→${NC} Enroll keys: ${CYAN}sudo sbctl enroll-keys --microsoft${NC}"
        echo -e "     ${YELLOW}(Use --microsoft flag for Windows dual-boot!)${NC}"
    fi

    echo -e "  ${YELLOW}→${NC} Enable Secure Boot in BIOS/UEFI"
    echo -e "     1. Reboot: ${CYAN}sudo reboot${NC}"
    echo -e "     2. Press DEL/F2/F12 to enter BIOS"
    echo -e "     3. Navigate to Boot → Secure Boot → Enable"
    echo -e "     4. Save and Exit"
else
    echo -e "${GREEN}✓ Secure Boot is ENABLED and working!${NC}"
    echo ""
    echo -e "  ${GREEN}→${NC} Test both operating systems boot correctly"
    echo -e "  ${GREEN}→${NC} Backup your keys: ${CYAN}sudo tar czf ~/sbctl-keys-backup.tar.gz /var/lib/sbctl/keys/${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}For more information, see: ${YELLOW}README.md${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
