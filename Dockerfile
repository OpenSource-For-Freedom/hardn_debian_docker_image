FROM registry.access.redhat.com/ubi9/ubi-minimal:9.5

LABEL org.opencontainers.image.title="HARDN-XDR (RHEL9, FIPS/STIG)"
LABEL org.opencontainers.image.description="HARDN-XDR with FIPS crypto policy and OpenSCAP STIG content on UBI9-minimal"
LABEL org.opencontainers.image.vendor="HARDN-XDR Project"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="1.0"

SHELL ["/bin/bash","-Eeuo","pipefail","-c"]

ENV LANG=C.UTF-8 \
    HARDN_XDR_HOME=/opt/hardn-xdr \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ARG HARDN_UID=10001
ARG HARDN_GID=10001

RUN microdnf -y update && \
    microdnf -y install \
      bash coreutils findutils grep sed awk tar xz \
      ca-certificates curl wget \
      openssl crypto-policies \
      openscap-scanner scap-security-guide \
      aide libpwquality \
      python3 python3-pip \
    && microdnf -y clean all

# userland crypto policy to FIPS (host should be FIPS-enabled for true compliance)
RUN update-crypto-policies --set FIPS || echo "WARN: Could not set FIPS (userland)"

RUN groupadd -g "${HARDN_GID}" -r hardn && \
    useradd  -u "${HARDN_UID}" -r -g hardn -d /home/hardn -m -s /usr/sbin/nologin hardn

WORKDIR ${HARDN_XDR_HOME}

COPY --chown=root:root --chmod=0755 rhel.hardn.sh /usr/local/bin/rhel.hardn.sh
COPY --chown=root:root --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=root:root --chmod=0755 smoke_test.sh /usr/local/bin/smoke_test.sh

USER hardn
WORKDIR /home/hardn

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD /usr/local/bin/smoke_test.sh || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash","-lc","exec bash"]
