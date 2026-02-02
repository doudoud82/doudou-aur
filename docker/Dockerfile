FROM archlinux:latest

USER root

# --- Enable multilib (if missing) ---
RUN grep -q '^\[multilib\]' /etc/pacman.conf || \
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' \
    | tee -a /etc/pacman.conf > /dev/null \
    && pacman -Syu --noconfirm

# Base system
RUN pacman -S --noconfirm \
    base-devel \
    git \
    gnupg \
    sudo \
    pacman-contrib

# Create non-root builder
RUN useradd -m builder \
    && echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER builder
WORKDIR /home/builder

# ---- Build aurutils from AUR ----
RUN git clone https://aur.archlinux.org/aurutils.git \
    && cd aurutils \
    && makepkg -si --noconfirm \
    && cd .. \
    && rm -rf aurutils

# Sanity check
RUN aur --version

# Remove the cache
RUN sudo pacman -Scc --noconfirm

# Runtime scripts
COPY entrypoint.sh /entrypoint.sh
COPY build.sh /build.sh
RUN sudo chmod +x /entrypoint.sh /build.sh

# Set up the local repo and keys
RUN printf '\n[doudou-aur]\nSigLevel = Optional TrustAll\nServer = file:///repo/x86_64\n' \
    | sudo tee -a /etc/pacman.conf
COPY doudou-aur.gpg /tmp/doudou-aur.gpg
RUN sudo pacman-key --init && \
    sudo pacman-key --populate archlinux && \
    sudo pacman-key --add /tmp/doudou-aur.gpg && \
    sudo pacman-key --lsign-key 3C6B7242

ENTRYPOINT ["/entrypoint.sh"]
