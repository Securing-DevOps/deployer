FROM golang:latest
RUN addgroup --gid 10001 app
RUN adduser --gid 10001 --uid 10001 \
    --home /app --shell /sbin/nologin \
    --disabled-password app

COPY bin/deployer /app/
RUN mkdir /app/deploymentTests
ADD deploymentTests /app/deploymentTests/

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get install jq

USER app
EXPOSE 8080
WORKDIR /app
CMD /app/deployer
