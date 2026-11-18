import re
import subprocess
from pathlib import Path

import libcalamares

LUKS_NAME = "cryptroot"
LIMINE_MARKER = "limine-mkinitcpio-hook"

BASE_HOOKS = [
    "base", "systemd", "keyboard", "autodetect", "microcode", "modconf",
    "kms", "sd-vconsole", "sd-numlock", "sd-encrypt", "block",
    "filesystems", "sd-btrfs-overlayfs", "fsck",
]

NVIDIA_PACKAGES = {"nvidia-open-dkms", "nvidia-580xx-dkms"}
NVIDIA_MODULES = ["nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"]

INTEL_LEGACY = "intel-compute-runtime-legacy"
I915_OPTIONS = "options i915 enable_guc=2\n"

MEMTEST_ESP = "EFI/memtest86+/memtest86x64.efi"

SD_MEMTEST_ENTRY = f"""\
title    Memtest86+
efi      /{MEMTEST_ESP}
sort-key z-memtest
"""

LIMINE_CONFIG = """\
TARGET_OS_NAME="Arch Linux"
ESP_PATH="@ESP@"
SKIP_UEFI=no
ENABLE_VERIFICATION=yes
BOOT_ORDER="*, *fallback, Snapshots"
ENABLE_SORT=yes
ENABLE_LIMINE_FALLBACK="no"
FIND_BOOTLOADERS=yes
ENABLE_ENROLL_LIMINE_CONFIG=yes
ENABLE_UKI=yes
SNAPSHOT_KERNEL_PARAMETERS-="quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3"
SNAPPER_CONFIG_NAME="root"
RESTORE_METHOD=replace
SNAPSHOT_FORMAT_CHOICE=2
HASH_FUNCTION=blake3
CUSTOM_UKI_NAME="arch"
"""

LOADER_CONF = """\
default @saved
timeout 5
console-mode max
editor no
beep off
"""

def pretty_name():
    return "Configuring kernel and bootloader"

# ----------------------------------------------------------------- helpers

def write_file(path, content, mode=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    if mode is not None:
        path.chmod(mode)


def target_call(cmd):
    """Run a command inside the target chroot; raise on failure."""
    rc = libcalamares.utils.target_env_call(cmd)
    if rc != 0:
        raise RuntimeError(f"Command failed ({rc}): {' '.join(cmd)}")


def get_selected_packages():
    """Package names queued by the choosers."""
    gs = libcalamares.globalstorage
    if not gs.contains("packageOperations"):
        return set()

    packages = set()
    for operation in gs.value("packageOperations") or []:
        if not isinstance(operation, dict):
            continue
        for action, entries in operation.items():
            if action not in {"install", "try_install", "localInstall"}:
                continue
            if not isinstance(entries, list):
                continue
            for entry in entries:
                if isinstance(entry, str):
                    packages.add(entry)
                elif isinstance(entry, dict) and isinstance(entry.get("package"), str):
                    packages.add(entry["package"])
    return packages


def get_encrypted_root_uuid():
    gs = libcalamares.globalstorage
    if not gs.contains("partitions"):
        return None
    for partition in gs.value("partitions") or []:
        if isinstance(partition, dict) and partition.get("mountPoint") == "/":
            luks_uuid = partition.get("luksUuid")
            if isinstance(luks_uuid, str) and luks_uuid:
                return luks_uuid
    return None


# ------------------------------------------------------------ configuration

def generate_fstab(root):
    """Write /etc/fstab from the mounted target (Calamares' fstab module isn't used)."""
    try:
        result = subprocess.run(["genfstab", "-U", str(root)],
                                check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"genfstab failed: {error.stderr}") from error

    fstab = result.stdout
    # Pinned subvolume ids break snapper/Limine rollbacks.
    fstab = re.sub(r",subvolid=\d+", "", fstab)
    # Keep the ESP (and its random-seed file) from being world-readable.
    fstab = fstab.replace("fmask=0022,dmask=0022", "umask=0077")

    if not any(line.strip() and not line.startswith("#")
               for line in fstab.splitlines()):
        raise RuntimeError("genfstab produced no mount entries.")

    write_file(root / "etc/fstab", fstab)

def configure_encryption(root, luks_uuid):
    """crypttab entry plus TPM2 PCR signing keys."""
    crypttab = root / "etc/crypttab"
    entry = (f"{LUKS_NAME} UUID={luks_uuid} none "
             "luks,tpm2-device=auto,discard,x-initrd.attach")

    kept = []
    if crypttab.exists():
        kept = [line for line in crypttab.read_text(encoding="utf-8").splitlines()
                if luks_uuid not in line]
    write_file(crypttab, "\n".join(kept + [entry]) + "\n")

    (root / "etc/systemd").mkdir(parents=True, exist_ok=True)
    target_call([
        "ukify", "genkey",
        "--pcr-private-key=/etc/systemd/tpm2-pcr-private-key.pem",
        "--pcr-public-key=/etc/systemd/tpm2-pcr-public-key.pem",
    ])
    (root / "etc/systemd/tpm2-pcr-private-key.pem").chmod(0o600)


def configure_mkinitcpio(root, limine, nvidia):
    config_dir = root / "etc/mkinitcpio.conf.d"
    hooks = [h for h in BASE_HOOKS if limine or h != "sd-btrfs-overlayfs"]
    write_file(config_dir / "99-doudou-hooks.conf",
               f"HOOKS=({' '.join(hooks)})\n")

    modules_file = config_dir / "99-doudou-modules.conf"
    if nvidia:
        write_file(modules_file, f"MODULES+=({' '.join(NVIDIA_MODULES)})\n")
    else:
        modules_file.unlink(missing_ok=True)

def configure_intel_igpu(root):
    config_dir = root / "etc/modprobe.d/i915.conf"
    write_file(config_dir,I915_OPTIONS)

# this is needed because limine is unable to read /etc/cmdline.d/*.conf
def write_kernel_cmdline(root):
    """Flatten /etc/cmdline.d/*.conf into /etc/kernel/cmdline (one line)."""
    parts = []
    for conf in sorted((root / "etc/cmdline.d").glob("*.conf")):
        for line in conf.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                parts.append(line)
    if not parts:
        raise RuntimeError("No kernel parameters found in /etc/cmdline.d.")
    write_file(root / "etc/kernel/cmdline", " ".join(parts) + "\n")


# -------------------------------------------------------------- bootloaders

def install_systemd_boot(root, esp):
    esp_dir = root / esp.lstrip("/")
    target_call(["bootctl", f"--esp-path={esp}", "install"])
    write_file(esp_dir / "loader/loader.conf", LOADER_CONF)
    if (esp_dir / MEMTEST_ESP).exists():
        write_file(esp_dir / "loader/entries/memtest86plus.conf", SD_MEMTEST_ENTRY)
    else:
        libcalamares.utils.warning("Memtest86+ is not on the ESP; no boot entry written.")


def install_limine(root, esp):
    write_file(root / "etc/default/limine",
               LIMINE_CONFIG.replace("@ESP@", esp))
    write_kernel_cmdline(root)


# --------------------------------------------------------------------- job

def run():
    gs = libcalamares.globalstorage
    if not gs.contains("rootMountPoint"):
        return ("Hardware configuration failed",
                "Calamares did not provide rootMountPoint.")
    root = Path(gs.value("rootMountPoint"))
    if not root.is_dir():
        return ("Hardware configuration failed",
                "The target root directory does not exist.")

    luks_uuid = get_encrypted_root_uuid()
    if not luks_uuid:
        return ("Hardware configuration failed",
                "Could not identify the encrypted root partition UUID.")

    esp = gs.value("efiSystemPartition") or "/efi"
    packages = get_selected_packages()
    limine = LIMINE_MARKER in packages
    nvidia = bool(packages & NVIDIA_PACKAGES)
    intel_legacy = INTEL_LEGACY in packages

    try:
        target_call(["pacman","-Sy","--needed","--noconfirm","--noprogressbar","doudou-system-config","memtest86+-efi"])
        (root / esp.lstrip("/") / MEMTEST_ESP).parent.mkdir(parents=True, exist_ok=True)
        target_call(["sbctl","sign","-s","-o",f"{esp}/{MEMTEST_ESP}","/boot/memtest86+/memtest86x64.efi"])
        generate_fstab(root)
        configure_encryption(root, luks_uuid)
        configure_mkinitcpio(root, limine, nvidia)
        if intel_legacy:
            configure_intel_igpu(root)
        install_systemd_boot(root, esp)
        if limine:
            install_limine(root, esp)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        libcalamares.utils.warning(str(error))
        return ("Hardware configuration failed", str(error))

    libcalamares.utils.debug(
        f"Hardware configuration: luks_uuid={luks_uuid}, esp={esp}, "
        f"limine={limine}, nvidia={nvidia}")
    return None