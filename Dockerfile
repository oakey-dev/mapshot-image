FROM debian:13.7-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

# Add this label to your Dockerfile
LABEL org.opencontainers.image.source=https://github.com/oakey-dev/mapshot-image

# Copy entrypoint script into the image
COPY --chmod=755 entrypoint.sh http-newest.awk /usr/local/bin/

# renovate: datasource=git-tags depName=https://github.com/Palats/mapshot
ENV MAPSHOT_VERSION="0.0.28"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    "ca-certificates=20250419" \
    "curl=8.14.1-2+deb13u5" \
    "file=1:5.46-5" \
    "gawk=1:5.2.1-2+b1" \
    "jq=1.7.1-6+deb13u3" \
    "procps=2:4.0.4-9" \
    "psmisc=23.7-2" \
    "xauth=1:1.1.2-1.1" \
    "xvfb=2:21.1.16-1.3+deb13u3" \
    "xz-utils=5.8.1-1+deb13u1" \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/mapshot "https://github.com/Palats/mapshot/releases/download/0.0.28/mapshot-linux" \
  && chmod +x /usr/local/bin/mapshot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
