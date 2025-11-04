#!/usr/bin/env bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo -e "${GREEN}==> Setting up build environment${NC}"
pacman -Sy reflector --noconfirm
reflector --country France,Germany,Spain,Sweden --latest 12 --number 5 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
cat >> /etc/pacman.conf <<EOF
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf
sed -i '/^OPTIONS=/s/debug/!debug/' /etc/makepkg.conf
sed -i "s/RUSTFLAGS=\"-C force-frame-pointers=yes\"/RUSTFLAGS=\"-C codegen-units=$(nproc) -C opt-level=3 -C force-frame-pointers=yes\"/" /etc/makepkg.conf.d/rust.conf
pacman -Syu base-devel git gnupg --noconfirm
echo -e "${GREEN}==> Importing GPG key${NC}"
GPG_PRIVATE_KEY=$(cat /run/secrets/gpg_private_key)
GPG_KEY_ID=$(cat /run/secrets/gpg_key_id)
echo "$GPG_PRIVATE_KEY" | gpg --batch --import
echo "GPG Key: $GPG_KEY_ID"
useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
REPO_DIR="/repo/x86_64"
BUILD_DIR="/build"
mkdir -p "$REPO_DIR"
mkdir -p "$BUILD_DIR"
chown -R builder:builder "$BUILD_DIR"
chown -R builder:builder "$REPO_DIR"

DEPENDENCIES=$(cat /repo/dependencies | grep -v '^#' | grep -v '^$')
echo -e "${YELLOW}==> Dependencies to build and install:${NC}"
echo "$DEPENDENCIES"
echo ""
echo -e "${GREEN}==> Cloning dependency PKGBUILDs from AUR${NC}"
cd "$BUILD_DIR"
for pkg in $DEPENDENCIES; do
    echo "Cloning $pkg..."
    su builder -c "git clone https://aur.archlinux.org/$pkg.git" || {
        echo -e "${RED}Failed to clone $pkg${NC}"
    }
done
echo ""
echo -e "${GREEN}==> Building and installing dependencies${NC}"
for pkg in $DEPENDENCIES; do
    echo ""
    echo -e "${GREEN}==> Building dependency: $pkg${NC}"
    cd "$BUILD_DIR/$pkg"
    su builder -c "makepkg -sf --noconfirm --skippgpcheck" || {
        echo -e "${RED}Failed to build dependency $pkg${NC}"
        continue
    }
    echo -e "${YELLOW}Installing dependency $pkg...${NC}"
    pacman -U --noconfirm ./*.pkg.tar.zst
    echo -e "${GREEN}✓ Installed dependency $pkg${NC}"
	echo "Removing old versions of $pkg..."
    rm -f "$REPO_DIR/$pkg-"*.pkg.tar.zst "$REPO_DIR/$pkg-"*.pkg.tar.zst.sig
	cp ./*.pkg.tar.zst "$REPO_DIR/"
    echo -e "${GREEN}✓ Built $pkg${NC}"
done

PACKAGES=$(cat /repo/packages | grep -v '^#' | grep -v '^$')
echo ""
echo -e "${YELLOW}==> Packages to build:${NC}"
echo "$PACKAGES"
echo ""
echo -e "${GREEN}==> Cloning package PKGBUILDs from AUR${NC}"
cd "$BUILD_DIR"
for pkg in $PACKAGES; do
    echo "Cloning $pkg..."
    su builder -c "git clone https://aur.archlinux.org/$pkg.git" || {
        echo -e "${RED}Failed to clone $pkg${NC}"
    }
done
echo ""
echo -e "${GREEN}==> Building packages${NC}"
for pkg in $PACKAGES; do
    echo ""
    echo -e "${GREEN}==> Building $pkg${NC}"
    cd "$BUILD_DIR/$pkg"
    
    su builder -c "makepkg -sf --noconfirm --skippgpcheck" || {
        echo -e "${RED}Failed to build $pkg${NC}"
        continue
    }
    echo "Removing old versions of $pkg..."
    rm -f "$REPO_DIR/$pkg-"*.pkg.tar.zst "$REPO_DIR/$pkg-"*.pkg.tar.zst.sig
    cp ./*.pkg.tar.zst "$REPO_DIR/"
    echo -e "${GREEN}✓ Built $pkg${NC}"
done

echo ""
echo -e "${GREEN}==> Signing packages${NC}"
cd "$REPO_DIR"
for pkg in *.pkg.tar.zst; do
    if [ -f "$pkg" ]; then
        echo "Signing $pkg..."
        rm -f "$pkg.sig"
        gpg --batch --yes --detach-sign --no-armor --passphrase "" "$pkg"
    fi
done
echo ""
echo -e "${GREEN}==> Creating repository database${NC}"
cd "$REPO_DIR"
rm -f doudou-aur.db* doudou-aur.files*
repo-add --sign --key "$GPG_KEY_ID" doudou-aur.db.tar.gz ./*.pkg.tar.zst

echo ""
echo -e "${GREEN}==> Fixing permissions${NC}"
REPO_UID=$(stat -c "%u" /repo)
REPO_GID=$(stat -c "%g" /repo)
chown -R "$REPO_UID:$REPO_GID" "$REPO_DIR"

echo ""
echo -e "${GREEN}==> Build completed successfully!${NC}"
echo -e "${YELLOW}==> Packages are in x86_64/${NC}"
echo -e "${YELLOW}==> Next: git add x86_64/ && git commit && git push${NC}"
