FROM rockylinux/rockylinux:8-minimal

# Install required packages
RUN microdnf update -y && microdnf install -y \
    openssh-server \
    sudo \
    python3 \
    net-tools \
    findutils \
    passwd \
    shadow-utils \
    procps-ng \
    && microdnf clean all

# Configure SSH server
RUN mkdir -p /var/run/sshd && \
    echo "Port 22" >> /etc/ssh/sshd_config && \
    echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> /etc/ssh/sshd_config && \
    echo "StrictModes no" >> /etc/ssh/sshd_config && \
    echo "LogLevel DEBUG3" >> /etc/ssh/sshd_config && \
    echo "SyslogFacility AUTH" >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# Copy test configuration
COPY test_config.sh /test_config.sh
RUN chmod +x /test_config.sh

# Create test groups
RUN groupadd mcc_live_hpc_posix_stats_inform

# Copy the user's SSH public key (if available)
COPY user_ssh_key.pub* /tmp/

# Copy container management script
COPY container_management.sh /container_management.sh
RUN chmod +x /container_management.sh

# Expose SSH port
EXPOSE 22

# Set healthcheck
HEALTHCHECK --interval=5s --timeout=10s --start-period=10s --retries=3 \
    CMD /container_management.sh healthcheck

# Start SSH server
CMD ["/container_management.sh", "start"] 