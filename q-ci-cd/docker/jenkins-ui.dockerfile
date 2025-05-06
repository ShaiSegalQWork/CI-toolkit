# Set default Ubuntu and Node.js versions if not provided
ARG UBUNTU_VERSION=20.04
ARG NODE_VERSION=20
ARG INSTALL_PYTHON="true"

FROM ubuntu:${UBUNTU_VERSION} AS base

SHELL ["/bin/bash", "-c"]

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt install tzdata -y
ENV TZ="Asia/Jerusalem"

RUN mkdir /var/lib/jenkins \ 
    && groupadd -g 5000 services \
    && useradd -r -u 5000 -g 5000 -d /var/lib/jenkins jenkins \
    && chown -R 5000:5000 /var/lib/jenkins 

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash git zip unzip build-essential libfuse2 ca-certificates make cmake software-properties-common squashfs-tools openssh-client && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt install -y python3.10 \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} \
    && apt install --no-install-recommends -y libportaudio2 python${PYTHON_VERSION}-distutils python${PYTHON_VERSION}-full python${PYTHON_VERSION}-dev && \
    rm -rf /var/lib/apt/lists/* ; \
    fi


USER jenkins

WORKDIR /var/lib/jenkins

USER jenkins

ENV HOME="/var/lib/jenkins"

# Install NVM
ENV NVM_DIR=$HOME/.nvm
ARG NODE_VERSION
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && \
    source $NVM_DIR/nvm.sh && \
    nvm install ${NODE_VERSION} && \
    nvm alias default ${NODE_VERSION} && \
    nvm use default && \
    npm install -g yarn

# Set PATH for Node.js
ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin:$PATH"

RUN source $NVM_DIR/nvm.sh 

RUN echo "source $NVM_DIR/nvm.sh" >> $HOME/.bashrc
ENV BASH_ENV=/var/lib/jenkins/.bashrc

CMD ["/bin/bash"]
