FROM --platform=linux/arm64 python:3.10.12

ENV PATH=":/home/jenkins/.local/bin:${PATH}"

COPY pip.config /etc/pip.conf

RUN  apt update \
    && apt install -y \ 
    git \
    make \
    cmake \
    libgtk2.0-dev\
    build-essential \
    libgstreamer1.0-0 \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    libgstreamer-plugins-base1.0-dev 

RUN mkdir /home/jenkins
RUN groupadd -g 5000 jenkins
RUN useradd -r -u 5000 -g jenkins -d /home/jenkins jenkins
RUN chown jenkins:jenkins /home/jenkins
USER jenkins
WORKDIR /home/jenkins

CMD ["/bin/bash"] 