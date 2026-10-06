FROM debian:13.7-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

# Add this label to your Dockerfile
LABEL org.opencontainers.image.source=https://github.com/oakey-dev/factorio-image

# Copy entrypoint script into the image
COPY --chmod=755 entrypoint.sh http-newest.awk /usr/local/bin/

# renovate: suite=trixie depName=ca-certificates
ENV CA_CERTIFICATES_VERSION="20250419"
# renovate: suite=trixie depName=curl
ENV CURL_VERSION="8.14.1-2+deb13u5"
# renovate: suite=trixie depName=file
ENV FILE_VERSION="1:5.46-5"
# renovate: suite=trixie depName=gawk
ENV GAWK_VERSION="1:5.2.1-2+b1"
# renovate: suite=trixie depName=jq
ENV JQ_VERSION="1.7.1-6+deb13u3"
# renovate: suite=trixie depName=procps
ENV PROCPS_VERSION="2:4.0.4-9"
# renovate: suite=trixie depName=psmisc
ENV PSMISC_VERSION="23.7-2"
# renovate: suite=trixie depName=xauth
ENV XAUTH_VERSION="1:1.1.2-1.1"
# renovate: suite=trixie depName=xvfb
ENV XVFB_VERSION="2:21.1.16-1.3+deb13u3"
# renovate: suite=trixie depName=xz-utils
ENV XZ_UTILS_VERSION="5.8.1-1+deb13u1"

# renovate: datasource=git-tags depName=https://github.com/Palats/mapshot
ENV MAPSHOT_VERSION="0.0.28"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    "ca-certificates=${CA_CERTIFICATES_VERSION}" \
    "curl=${CURL_VERSION}" \
    "file=${FILE_VERSION}" \
    "gawk=${GAWK_VERSION}" \
    "jq=${JQ_VERSION}" \
    "procps=${PROCPS_VERSION}" \
    "psmisc=${PSMISC_VERSION}" \
    "xauth=${XAUTH_VERSION}" \
    "xvfb=${XVFB_VERSION}" \
    "xz-utils=${XZ_UTILS_VERSION}" \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL -o /usr/local/bin/mapshot "https://github.com/Palats/mapshot/releases/download/${MAPSHOT_VERSION}/mapshot-linux" \
  && chmod +x /usr/local/bin/mapshot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
