FROM archlinux:latest

USER root

RUN grep -q '^\[multilib\]' /etc/pacman.conf || \
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' \
    | tee -a /etc/pacman.conf > /dev/null

RUN sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
RUN sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf
RUN sed -i '/^OPTIONS=/s/debug/!debug/' /etc/makepkg.conf
RUN sed -i "s/RUSTFLAGS=\"-C force-frame-pointers=yes\"/RUSTFLAGS=\"-C codegen-units=$(nproc) -C opt-level=3 -C force-frame-pointers=yes\"/" /etc/makepkg.conf.d/rust.conf

RUN pacman -Syu --noconfirm \
    base-devel \
    git \
    gnupg \
    sudo \
    pacman-contrib nano

RUN useradd -m builder \
    && echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER builder
WORKDIR /home/builder

RUN git clone https://aur.archlinux.org/aurutils.git \
    && cd aurutils \
    && makepkg -si --noconfirm \
    && cd .. \
    && rm -rf aurutils

RUN sudo pacman -Scc --noconfirm

RUN printf '\n[doudou-aur]\nSigLevel = Optional TrustAll\nServer = file:///repo/x86_64\n' \
    | sudo tee -a /etc/pacman.conf
ARG GPGKEY
RUN sudo pacman-key --init
RUN sudo pacman-key --populate archlinux
RUN sudo pacman-key --recv-key ${GPGKEY}
RUN sudo pacman-key --lsign-key ${GPGKEY}

COPY entrypoint.sh /entrypoint.sh
COPY build.sh /build.sh
RUN sudo chmod +x /entrypoint.sh /build.sh

ENTRYPOINT ["/entrypoint.sh"]
