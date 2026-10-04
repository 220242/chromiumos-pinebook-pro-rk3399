# Build infrastructure for ChromiumOS PineBook Pro RK3399

This directory contains build scripts, utilities, and Windows integration for compiling ChromiumOS with full support for PineBook Pro storage targets (microSD, eMMC, NVMe).

## Directory structure

```
build/
├── linux/                    # Core build scripts (run on Linux/WSL2)
│   ├── verify-tree.sh       # Static verification
│   ├── preflight.sh         # System readiness check
│   ├── sync.sh              # Fetch ChromiumOS source
│   ├── build-kernel.sh      # Build Linux kernel
│   ├── build-uboot.sh       # Build U-Boot bootloader
│   ├── build.sh             # Main ChromiumOS build
│   └── build-images.sh      # Generate final disk images
│
├── windows/                  # Windows PowerShell integration
│   ├── Start-PinebookBuild.ps1         # Main orchestrator
│   ├── Invoke-WSL.ps1                  # WSL2 wrapper
│   └── Copy-Artifacts.ps1              # Extract results to Windows
│
├── lib/                      # Shared utilities
│   ├── lib-tree.sh          # Tree/path utilities
│   ├── lib-log.sh           # Logging functions
│   └── lib-config.sh        # Configuration helpers
│
├── dev/                      # Development utilities
│   ├── gen-device-tree.sh   # Generate device tree overlays
│   └── format-storage.sh    # Partition and format media
│
└── README.md                 # This file
```

## Usage patterns

See `docs/WINDOWS_BUILD.md` for detailed build workflow.

### Quick start on Linux/WSL2

```bash
cd /path/to/chromiumos

build/verify-tree.sh
build/preflight.sh
build/sync.sh
build/build-kernel.sh
build/build-uboot.sh
build/build.sh userdebug
build/build-images.sh
```

### From Windows PowerShell 7

```powershell
cd D:\chromiumos
pwsh -ExecutionPolicy Bypass -File .\android_manifest\build\windows\Start-PinebookBuild.ps1
```

## Environment variables

All scripts support:

- `CHROMIUMOS_ROOT` - Override automatic tree detection
- `BUILD_CORES` - Number of parallel jobs (default: nproc)
- `LOG_DIR` - Output directory for logs (default: output/logs)
- `VERBOSE` - Enable verbose output (1 = yes, 0 = no)
- `DRY_RUN` - Show commands without executing (1 = yes)

## Logging

All build logs go to `output/logs/` with timestamp:

```bash
# View live log
tail -f output/logs/build-*.log

# Search for errors
grep -i "error\|fail\|warning" output/logs/*.log

# Archive logs
tar czf output/logs-backup-$(date +%Y%m%d).tar.gz output/logs
```

## Key scripts

### `build/linux/verify-tree.sh`

Static checks that don't require source:

```bash
build/linux/verify-tree.sh [tree-root]

# Verifies:
# - Device tree syntax
# - Kernel config validity
# - U-Boot defconfig present
# - Build configuration files

# Exit code: 0 = valid, non-zero = issues
```

### `build/linux/sync.sh`

Fetch ChromiumOS and all dependencies:

```bash
build/linux/sync.sh [tree-root]

# Optional tree-root:
#   Default: ~/chromiumos, ~/aosp
#   Can be explicit path like /mnt/d/chromiumos

# Creates:
#   .repo/          (manifest and metadata)
#   chromiumos/     (platform sources)
#   third_party/    (kernel, U-Boot, etc.)

# Network: ~120GB download (takes 30-60 min)
# Disk: ~200GB after sync
```

### `build/linux/build-kernel.sh`

Compile Linux kernel with ChromiumOS config:

```bash
build/linux/build-kernel.sh [tree-root] [target]

# Arguments:
#   tree-root: path to ChromiumOS checkout
#   target: emmc, microsd, or nvme (default: all)

# For single target:
build/linux/build-kernel.sh /mnt/d/chromiumos microsd

# Outputs:
#   arch/arm64/boot/Image
#   arch/arm64/boot/dts/rockchip/pinebook-pro-rk3399-*.dtb
#   modules/

# Time: 10-20 minutes depending on cores
```

### `build/linux/build-uboot.sh`

Compile U-Boot bootloader:

```bash
build/linux/build-uboot.sh [tree-root]

# Outputs:
#   u-boot.bin
#   u-boot-dtb.bin

# Time: 2-5 minutes
```

### `build/linux/build.sh`

Main ChromiumOS build (rootfs, binaries, etc.):

```bash
build/linux/build.sh [target] [tree-root]

# Arguments:
#   target: userdebug (default), release, test, etc.
#   tree-root: path to ChromiumOS checkout

# Example:
build/linux/build.sh userdebug /mnt/d/chromiumos

# Outputs:
#   out/board_name/latest/
#     ├── rootfs.img
#     ├── recovery_image.bin
#     └── other.bin

# Time: 30-60 minutes
```

### `build/linux/build-images.sh`

Generate final bootable images:

```bash
build/linux/build-images.sh [tree-root] [format]

# Arguments:
#   tree-root: path to ChromiumOS checkout
#   format: img (default) or raw

# Outputs:
#   output/images/
#     ├── chromiumos-pinebook-pro-microsd.img.gz
#     ├── chromiumos-pinebook-pro-emmc.img.gz
#     ├── chromiumos-pinebook-pro-nvme.img.gz
#     └── SHA256SUMS

# Time: 5-10 minutes (mostly compression)
# Size: ~512MB-2GB per image (gzipped)
```

## Windows PowerShell scripts

### `build/windows/Start-PinebookBuild.ps1`

Main orchestrator for Windows 11:

```powershell
# Run from Windows PowerShell 7
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

cd D:\chromiumos
.\android_manifest\build\windows\Start-PinebookBuild.ps1

# Or:
pwsh -ExecutionPolicy Bypass -File .\android_manifest\build\windows\Start-PinebookBuild.ps1
```

**Options**:
```powershell
# Full build:
.\Start-PinebookBuild.ps1 -Full

# Only kernel:
.\Start-PinebookBuild.ps1 -KernelOnly

# Only images:
.\Start-PinebookBuild.ps1 -ImagesOnly
```

**What it does**:
1. Checks prerequisites (WSL2, disk space, Git)
2. Mounts D: in WSL2 if needed
3. Runs build sequence with logging
4. Copies artifacts back to Windows
5. Generates summary report

## Parallel builds

Increase build speed with more cores:

```bash
# Auto-detect (uses all cores):
build/linux/build-kernel.sh

# Force specific core count:
BUILD_CORES=16 build/linux/build-kernel.sh

# For 8 cores:
BUILD_CORES=8 build/linux/build.sh userdebug
```

## Clean builds

```bash
# Clean kernel only:
rm -rf third_party/kernel/out

# Clean U-Boot:
rm -rf third_party/u-boot/out

# Clean ChromiumOS build:
rm -rf out/

# Full clean:
rm -rf out/ third_party/kernel/out third_party/u-boot/out
```

## Incremental development

**Workflow for rapid iteration**:

1. Make code changes (kernel, U-Boot, etc.)
2. Run only the affected build step:
   ```bash
   # After kernel config change:
   build/linux/build-kernel.sh
   build/linux/build-images.sh
   
   # After rootfs change:
   build/linux/build.sh userdebug
   build/linux/build-images.sh
   
   # After U-Boot change:
   build/linux/build-uboot.sh
   build/linux/build-images.sh
   ```
3. Flash new image to microSD
4. Boot and test
5. Repeat

**Total iteration time**: 10-30 minutes (vs 1.5-2 hours for full build)

## Logging and diagnostics

### Automatic logging

Every script logs to `output/logs/` with:
- Timestamp
- Script name
- Status (INFO, WARN, ERROR, SUCCESS)
- Command output (captured stderr/stdout)

### Example log format

```
2026-10-04 06:30:00 [INFO] Starting kernel build
2026-10-04 06:30:05 [INFO] Tree root: /mnt/d/chromiumos
2026-10-04 06:30:10 [CMD] make ARCH=arm64 -j8 Image
2026-10-04 06:45:30 [SUCCESS] Kernel Image ready
2026-10-04 06:46:00 [CMD] make ARCH=arm64 -j8 dtbs
2026-10-04 06:46:15 [SUCCESS] Device trees ready
2026-10-04 06:46:20 [INFO] Kernel build complete (15m20s)
```

### View logs

```bash
# Real-time:
tail -f output/logs/build-*.log

# Find errors:
grep ERROR output/logs/*.log

# Check specific stage:
cat output/logs/build-kernel-2026-10-04-*.log | tail -50
```

## Advanced options

### Dry run (show commands without executing)

```bash
DRY_RUN=1 build/linux/build-kernel.sh
```

### Verbose output

```bash
VERBOSE=1 build/linux/build.sh userdebug
```

### Custom tree path

```bash
CHROMIUMOS_ROOT=/custom/path build/linux/sync.sh
```

## Summary

The build infrastructure provides:

1. **Linux/WSL2 core scripts** for actual compilation
2. **Windows PowerShell integration** for orchestration on Windows 11
3. **Automatic logging** for all build steps
4. **Support for three storage targets** (microSD, eMMC, NVMe)
5. **Fast iteration workflow** for development
6. **Complete diagnostic information** for troubleshooting

Total build time: 1.5-2 hours (first full build), 10-30 minutes (incremental)
