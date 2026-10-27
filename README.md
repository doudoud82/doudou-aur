# My Arch Linux Repository
[![GitHub Pages Build](https://github.com/doudoud82/doudou-aur/actions/workflows/github-pages.yaml/badge.svg)](https://github.com/doudoud82/doudou-aur/actions/workflows/github-pages.yaml)
[![Github Pages Deployment](https://github.com/doudoud82/doudou-aur/actions/workflows/pages/pages-build-deployment/badge.svg?branch=gh-pages)](https://github.com/doudoud82/doudou-aur/actions/workflows/pages/pages-build-deployment)

Personal Arch Linux package repository hosted on GitHub Pages with automated builds from AUR.

## Requirement
Podman is a requirement to build the packages.

## 📦 Available Packages
List of the main packages this repo adds
- doudou-aur-keyring
- doudou-aur-mirrorlist
- mkinitcpio-sd-numlock
- ab-download-manager-bin
- capt-src
- gtk2
- lib32-libxml2-legacy
- lib32-popt
- libglade


## 🚀 Usage

### 1. Import GPG Key and install the keyring and mirrorlist
```bash
sudo sudo pacman-key --recv-key 063F6A5182A1B15D
sudo pacman-key --lsign-key 063F6A5182A1B15D
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

### To build or update the repo
In order to rebuild everything do:
```bash
./run-build.sh --all
```
or to build specific packages inorder do:
```bash
./run-build.sh <pkg1> <pkg2>
```

### Adding New Packages
To add a new package use the helper shell script
```bash
./add-aur-package.sh <AUR URL>
```
> [!NOTE]
> Added packages are automatically appended to `packages.txt` to be included in `./run-build.sh --all`. If the package has dependencies from AUR ensure they are added before the package `packages.txt`.

## 📝 License

Packages retain their original licenses from AUR. See individual package PKGBUILD at [AUR](https://aur.archlinux.org/) for details.

## 🔗 Links

- [AUR](https://aur.archlinux.org/)
- [Arch Wiki - Custom Local Repository](https://wiki.archlinux.org/title/Custom_local_repository)
