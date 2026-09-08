FROM alpine:3.20

RUN apk add --no-cache \
    nut \
    nut-server \
    nut-client \
    tini

# Create NUT runtime directories
RUN mkdir -p /var/run/nut /etc/nut && \
    chown -R root:root /var/run/nut /etc/nut && \
    chmod 755 /var/run/nut /etc/nut

# Expose NUT port
EXPOSE 3493

# Basic NUT config - upsd listens on all interfaces
RUN echo 'LISTEN 0.0.0.0 3493' > /etc/nut/upsd.conf && \
    echo 'LISTEN :: 3493' >> /etc/nut/upsd.conf && \
    echo 'MODE master' >> /etc/nut/nutdrv_qx.conf

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["upsd", "-D"]
