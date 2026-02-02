# My Arch Linux Repository
[![GitHub Pages Build](https://github.com/doudoud82/doudou-aur/actions/workflows/github-pages.yaml/badge.svg)](https://github.com/doudoud82/doudou-aur/actions/workflows/github-pages.yaml)

Personal Arch Linux package repository hosted on GitHub Pages with automated builds from AUR.

## Requirement
Docker is a requirement to build the packages.

## 📦 Available Packages
List of the main packages this repo adds
- ab-download-manager-bin
- capt-src
- mkinitcpio-sd-numlock


## 🚀 Usage

### 1. Import GPG Key and install the keyring and mirrorlist
```bash
curl -O --output-dir /tmp https://doudoud82.github.io/doudou-aur/doudou-aur.gpg
sudo pacman-key --add /tmp/doudou-aur.gpg
sudo pacman-key --lsign-key 3E7914503C6B7242
sudo pacman -U https://doudoud82.github.io/doudou-aur/x86_64/doudou-aur-keyring-2026.02.02-1-any.pkg.tar.zst
sudo pacman -U https://doudoud82.github.io/doudou-aur/x86_64/doudou-aur-mirrorlist-2026.02.02-1-x86_64.pkg.tar.zst
```

### 2. Add Repository to Pacman

Edit `/etc/pacman.conf` and add:
```ini
[doudou-aur]
SigLevel = Required DatabaseOptional
Server = /etc/pacman.d/doudou-aur-mirrorlist
```

### 3. Install Packages
For example:
```bash
sudo pacman -Sy
sudo pacman -S capt-src
```

## 📋 Package List

View all available packages: [Browse x86_64/](https://github.com/doudoud82/doudou-aur/tree/master/x86_64)

## ⚙️ Repository Details

- **Repository Name**: doudou-aur
- **Architecture**: x86_64
- **Signature Level**: Required

## 🛠️ For Maintainer

### Adding New Packages
Just add the package name in the packages file.

And finally call `./run-build-docker.sh`

## 📝 License

Packages retain their original licenses from AUR. See individual package PKGBUILD at [AUR](https://aur.archlinux.org/) for details.

## 🔗 Links

- [AUR](https://aur.archlinux.org/)
- [Arch Wiki - Custom Local Repository](https://wiki.archlinux.org/title/Custom_local_repository)
