# Use Alpine Linux as base image
FROM alpine:latest

ENV PATH=":/var/lib/jenkins:${PATH}"

RUN apk update \
    && apk add --no-cache \
    jq \
    tar \
    bash \
    pigz \
    aws-cli \
    openssh \
    postgresql16-client 

RUN mkdir /var/lib/jenkins
RUN addgroup --gid 5000 services
RUN adduser --uid 5000 --ingroup services --home /var/lib/jenkins --no-create-home --disabled-password jenkins
RUN chown -R jenkins:services /var/lib/jenkins
USER jenkins
WORKDIR /var/lib/jenkins