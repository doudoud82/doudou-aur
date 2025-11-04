# My Arch Linux Repository

Personal Arch Linux package repository hosted on GitHub Pages with automated builds from AUR.

## Requirement
Docker is a hard requirement to build the packages.

## 📦 Available Packages
List of the main packages this repo adds
- capt-src
- limine-mkinitcpio-hook

### 📦 Available Packages dependency
The following packages are also provided because they are runtime dependencies from AUR.
- gtk2
- libglade
- lib32-libxml2-legacy

## 🚀 Usage

### 1. Import GPG Key
```bash
curl -O --output-dir /tmp https://doudoud82.github.io/doudou-aur/doudou-aur.gpg
sudo pacman-key --add /tmp/doudou-aur.gpg
sudo pacman-key --lsign-key 3E7914503C6B7242
```

### 2. Add Repository to Pacman

Edit `/etc/pacman.conf` and add:
```ini
[doudou-aur]
SigLevel = Required DatabaseOptional
Server = https://doudoud82.github.io/$repo/$arch
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

If a package have dependency from AUR please add them to the dependencies file.

And finally call `./update-repo.sh`

## 📝 License

Packages retain their original licenses from AUR. See individual package PKGBUILD for details.

## 🔗 Links

- [AUR](https://aur.archlinux.org/)
- [Arch Wiki - Custom Local Repository](https://wiki.archlinux.org/title/Custom_local_repository)
