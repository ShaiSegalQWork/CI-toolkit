# Use Alpine Linux as base image
FROM python:3.10-slim-bullseye

ENV PATH=":/var/lib/jenkins:${PATH}"

RUN mkdir /var/lib/jenkins
RUN addgroup --gid 5000 services
RUN adduser --uid 5000 --gid 5000 --home /var/lib/jenkins --no-create-home --disabled-password jenkins
RUN chown -R jenkins:services /var/lib/jenkins

RUN apt update \
    && apt install -y \
    jq \
    tar \
    gcc \
    bash \
    curl \
    pigz \
    unzip \
    rsync \
    rclone \
    libpq-dev 
    
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

USER jenkins
WORKDIR /var/lib/jenkins

COPY requirements.txt ./requirements.txt
COPY q_cue_data_models-0.9.0-py3-none-linux_x86_64.whl ./q_cue_data_models-0.9.0-py3-none-linux_x86_64.whl 

RUN python3.10 -m venv venv \
    && . venv/bin/activate \
    && pip install -r ./requirements.txt \
    && pip install q_cue_data_models-0.9.0-py3-none-linux_x86_64.whl \
    && deactivate 