FROM busybox:latest
RUN addgroup -g 10001 app && \
    adduser -G app -u 10001 \
    -D -h /app -s /sbin/nologin app

COPY bin/deployer /app/deployer
USER app
EXPOSE 8080
WORKDIR /app
ENTRYPOINT /app/deployer
