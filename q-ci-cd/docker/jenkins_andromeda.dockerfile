ARG BASE_DOCKER_IMAGE="harbor.q.ai/cross-compilation/ubuntu-focal-recorder@sha256:04f85025376b56939f1a2744e669935ba806a39997be11fff4cebfc2793f7e50"
FROM ${BASE_DOCKER_IMAGE}

RUN mkdir /var/lib/jenkins \ 
    && groupadd -g 5000 services \
    && useradd -r -u 5000 -g 5000 -d /var/lib/jenkins jenkins \
    && chown -R 5000:5000 /var/lib/jenkins 

COPY pip.config /etc/pip.conf

RUN apt update\
    && apt install -y \
    tar \
    wget \
    curl \
    gnupg \
    ca-certificates \
    clang-format-11 \ 
    lib32ncurses-dev 

RUN cd /usr/local/share/ca-certificates/ \
    && wget --no-check-certificate https://wiki.q.ai/ca.crt \
    && update-ca-certificates

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt update \
    && apt install -y nodejs \
    && npm install -g yarn

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

WORKDIR /var/lib/jenkins

USER jenkins

ENV HOME="/var/lib/jenkins"
ENV PATH="/usr/bin/node:$PATH"

CMD ["/bin/bash"]