# Overview
Dockerfiles for Q recorder project and jenkins pipelines.

## Login
Login into Q Harbor: `docker login harbor.q.ai`

## focal-recorder.dockerfile
A dockerfile to build a docker image meant for recorder cross compilation and run.  
1. To build the docker for Ubuntu x86, run:
`docker buildx build -t ubuntu-focal-recorder:latest --pull --platform linux/amd64 -f ./focal-recorder.dockerfile ../`
2. Tag the docker to Q's Harbor:  
`docker image tag ubuntu-focal-recorder:latest harbor.q.ai/cross-compilation/ubuntu-focal-recorder:latest`  
3. Push the new docker:  
`docker push harbor.q.ai/cross-compilation/ubuntu-focal-recorder:latest`  
## l4t-recorder.dockerfile
A dockerfile to build a docker image meant for recorder cross compilation and run.  
1. To build the docker for L4T (Jetson), run:  
`docker buildx build -t l4t-35.1.0-recorder:latest --pull --platform linux/arm64 -f ./l4t-recorder.dockerfile ../`  
2. Tag the docker to Q's Harbor:
`docker image tag l4t-35.1.0-recorder:latest harbor.q.ai/cross-compilation/l4t-35.1.0-recorder:latest`  
3. Push the new docker:  
`docker push harbor.q.ai/cross-compilation/l4t-35.1.0-recorder:latest`  

## jenkins_andromeda.dockerfile

1.  Takes image as build arg:
    https://harbor.q.ai/harbor/projects/6/repositories/ubuntu-focal-recorder (focal-recorder.dockerfile)

2. Requires folder's and files within the build context:
    * https://www.infineon.com/cms/en/design-support/tools/sdk/usb-controllers-sdk/ez-usb-fx3-software-development-kit/ untar 32 bit to following structure: 
    FX3_SDK_1.3.4_Linux:
        -> arm-2013.11
        -> cyfx3sdk
    * pip.conf

3. Build and push: 

    1. `docker login harbor.q.ai`

    2. `docker build --build-arg="BASE_DOCKER_IMAGE=harbor.q.ai/cross-compilation/ --platform <platform> ubuntu-focal-recorder@sha256:b17b9217d5ada4946cb4b2f40f3dd02124191124e779b57f67fc4b85e66baccb" -t harbor.q.ai/devops/ubuntu-focal-recorder:<tag> -f ./docker/jenkins_andromeda.dockerfile .`


    3. `docker push harbor.q.ai/devops/ubuntu-focal-recorder:<tag>`  

## jenkins_python.dockerfile

1.  Remember to build for both --platform=linux/(arm64\amd64) for CI uses in line 1 of dockerfile.

2. Build and push: 

    1. `docker login harbor.q.ai`

    2. `docker build -t harbor.q.ai/devops/python:<tag> -f ./docker/jenkins_andromeda.dockerfile .`

    3. `docker push harbor.q.ai/devops/python:<tag>`  