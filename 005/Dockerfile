FROM ubuntu:bionic

RUN apt-get update && \
    apt-get install -y curl zip git && \
    curl -L -o terraform.zip https://releases.hashicorp.com/terraform/1.0.0/terraform_1.0.0_linux_amd64.zip && \
    unzip terraform.zip

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install

WORKDIR /input

USER nobody:nogroup

ENTRYPOINT ["/terraform"]
