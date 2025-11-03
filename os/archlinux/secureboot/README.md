# Secure Boot Setup for Arch Linux + Windows Dual Boot

Complete guide for configuring Secure Boot on Arch Linux with Windows dual-boot using sbctl.

## Quick Start

```bash
# 1. Run the automated setup
cd ~/code/dotfiles/os/archlinux/secureboot
sudo ./setup-secureboot.sh

# 2. Check current status
./check-status.sh

# 3. Enter BIOS and clear Secure Boot keys (see BIOS Setup below)

# 4. Enroll keys with Microsoft keys for Windows
sudo sbctl enroll-keys --microsoft

# 5. Reboot and enable Secure Boot in BIOS
```

---

## Current System Configuration

- **Bootloader**: systemd-boot 257.4-1-arch
- **Firmware**: UEFI 2.90 (American Megatrends 5.26 - ASUS)
- **OS**: EndeavourOS (Arch Linux) + Windows
- **Dual Boot**: Separate partitions

---

## BIOS Setup Steps

### Step 1: Clear Secure Boot Keys (Enable Setup Mode)

1. Reboot: `sudo reboot`
2. Press **DEL** or **F2** during boot (ASUS motherboard)
3. Navigate to: **Boot** → **Secure Boot** or **Security** → **Secure Boot**
4. Look for and select one of these options:
   - "Clear Secure Boot Keys"
   - "Delete all Secure Boot variables"
   - "Reset to Setup Mode"
   - "Restore Factory Keys" then delete them
5. **Save and Exit** (F10)
6. Boot into Linux

### Step 2: Verify Setup Mode

```bash
sudo sbctl status
# Should show: Setup Mode: ✓ Enabled
```

### Step 3: Enroll Keys

```bash
# Enroll YOUR keys + MICROSOFT keys (for Windows)
sudo sbctl enroll-keys --microsoft
```

### Step 4: Enable Secure Boot

1. Reboot: `sudo reboot`
2. Press **DEL** or **F2** to enter BIOS
3. Navigate to: **Boot** → **Secure Boot**
4. Set **Secure Boot** to **Enabled**
5. **Save and Exit** (F10)

### Step 5: Verify

```bash
sudo sbctl status
# Should show: Secure Boot: ✓ Enabled
```

---

## Manual Commands

### Check Status
```bash
sudo sbctl status              # Overall status
./check-status.sh              # Detailed status
bootctl status                 # Boot configuration
```

### Create and Sign
```bash
sudo sbctl create-keys         # Create signing keys (one time)
sudo sbctl sign -s /path/to/file.efi  # Sign a file
sudo sbctl sign-all            # Sign all enrolled files
sudo sbctl verify              # Check signed files
```

### Key Management
```bash
sudo sbctl list-enrolled-keys  # Show keys in firmware
sudo sbctl enroll-keys --microsoft  # Enroll with Windows support
sudo sbctl reset               # Clear enrolled keys
```

### Backup Keys
```bash
# Backup (IMPORTANT - store safely!)
sudo tar czf ~/sbctl-keys-backup-$(date +%Y%m%d).tar.gz /var/lib/sbctl/keys/

# Restore
sudo tar xzf sbctl-keys-backup-YYYYMMDD.tar.gz -C /
```

---

## Troubleshooting

### "System not in Setup Mode" Error

**Solution**: Clear Secure Boot keys in BIOS (see BIOS Setup above)

### Windows Won't Boot

**Cause**: Microsoft keys not enrolled

**Solution**:
1. Disable Secure Boot in BIOS
2. Boot Linux
3. Re-enroll: `sudo sbctl enroll-keys --microsoft`
4. Enable Secure Boot in BIOS

### Linux Won't Boot

**Cause**: Bootloader/kernel not signed

**Solution**:
1. Disable Secure Boot in BIOS
2. Boot Linux
3. Sign files: `sudo sbctl sign-all`
4. Verify: `sudo sbctl verify`
5. Enable Secure Boot in BIOS

### After Kernel Update

Automatic signing is configured via pacman hook at:
`/etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook`

If automatic signing fails, manually sign:
```bash
sudo sbctl sign-all
```

---

## Files and Locations

### Signing Keys
```
/var/lib/sbctl/keys/
├── PK/PK.key       # Platform Key
├── KEK/KEK.key     # Key Exchange Key
└── db/db.key       # Signature Database Key
```

### EFI Boot Files
```
/efi/
├── EFI/systemd/systemd-bootx64.efi  # Bootloader (signed)
├── EFI/BOOT/BOOTX64.EFI             # Fallback (signed)
├── EFI/Microsoft/Boot/              # Windows files (Microsoft signed)
└── {machine-id}/{kernel-ver}/linux  # Kernel (signed)
```

### Configuration
```
/etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook  # Auto-sign
```

---

## How It Works

1. **Keys Created**: Your custom signing keys (PK, KEK, db)
2. **Files Signed**: Linux bootloader and kernel signed with your db key
3. **Keys Enrolled**: Both your keys AND Microsoft keys enrolled in firmware
4. **Secure Boot On**: Firmware only boots signed files
5. **Dual Boot Works**: 
   - Linux files signed by YOUR key ✓
   - Windows files signed by MICROSOFT key ✓
   - Both keys in firmware → both OS boot ✓

---

## Important Notes

- **initrd/initramfs** files don't need signing (not EFI executables)
- **Microsoft files** showing "not signed" in `sbctl verify` is normal
- **Always use --microsoft flag** when enrolling keys for dual-boot
- **Backup keys** before major system changes
- **Test both OS** after enabling Secure Boot

---

## Scripts

- `setup-secureboot.sh` - Automated setup (creates keys, signs files)
- `check-status.sh` - Display current Secure Boot status
- `999-sign_kernel_for_secureboot.hook` - Auto-sign kernels on update

---

## References

- [Arch Wiki: Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
- [sbctl GitHub](https://github.com/Foxboron/sbctl)