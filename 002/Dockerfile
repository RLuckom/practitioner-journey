FROM ubuntu:bionic

RUN apt-get update && \
    apt-get install -y curl zip git && \
    curl -L -o terraform.zip https://releases.hashicorp.com/terraform/0.14.0/terraform_0.14.0_linux_amd64.zip && \
    unzip terraform.zip

WORKDIR /input

USER nobody:nogroup

ENTRYPOINT ["/terraform"]
