# Privileged builder image for customizing Raspberry Pi OS arm64 images.
# Run with: docker run --privileged -v ... (see deploy/pi-image/README.md)

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    xz-utils \
    util-linux \
    mount \
    qemu-user-static \
    qemu-utils \
    parted \
    cloud-guest-utils \
    e2fsprogs \
    dosfstools \
    rsync \
    file \
    openssl \
    fdisk \
    kpartx \
    grep \
    gawk \
    coreutils \
  && rm -rf /var/lib/apt/lists/*

COPY build-pi-image.sh /usr/local/bin/build-pi-image.sh
RUN sed -i 's/\r$//' /usr/local/bin/build-pi-image.sh \
  && chmod +x /usr/local/bin/build-pi-image.sh

WORKDIR /work

# Avoid CRLF shebang issues when the repo is checked out on Windows.
ENTRYPOINT ["/bin/bash", "/usr/local/bin/build-pi-image.sh"]
