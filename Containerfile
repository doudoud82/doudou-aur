FROM archlinux:multilib-devel

USER root

RUN sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf \
    && sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf \
    && sed -i '/^OPTIONS=/s/debug/!debug/' /etc/makepkg.conf \
    && sed -i "s/RUSTFLAGS=\"-C force-frame-pointers=yes\"/RUSTFLAGS=\"-C codegen-units=$(nproc) -C opt-level=3 -C force-frame-pointers=yes\"/" /etc/makepkg.conf.d/rust.conf

RUN pacman -Syu --noconfirm git pacman-contrib

RUN useradd -m builder \
    && echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER builder
WORKDIR /home/builder

RUN sudo pacman -Scc --noconfirm

RUN printf '\n[doudou-aur]\nSigLevel = Optional TrustAll\nServer = file:///repo/x86_64\n' \
    | sudo tee -a /etc/pacman.conf
ARG GPGKEY
RUN sudo pacman-key --init
RUN sudo pacman-key --populate archlinux
RUN sudo pacman-key --recv-key ${GPGKEY}
RUN sudo pacman-key --lsign-key ${GPGKEY}

COPY pkgbuilds /repo/pkgbuilds
COPY entrypoint.sh /entrypoint.sh
COPY build.sh /build.sh
RUN sudo chmod +x /entrypoint.sh /build.sh

ENTRYPOINT ["/entrypoint.sh"]
