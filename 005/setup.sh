#!/usr/bin/sh

# "set -e" means to exit if there are errors
set -e

# "snap" is an installation tool. For this exercise, we need to install docker and the command-line interface (cli) for aws
snap install --classic aws-cli

# Docker is a "container" tool. It lets you package up the whole environment in which a program runs, ensuring that
# it will run the same way on any system. We're going to use docker to run terraform so that as operating-system versions
# change (or if we want to run it on local machines) everything that matters will stay the same.
snap install docker

# Wait five seconds so that docker has time to start up.
sleep 5

# This command builds the docker container according to a text script called a "Dockerfile" located in this directory
docker build -t terraform -f Dockerfile .

# Create a command for running terraform in docker
echo 'sudo docker run --rm -ti --user=$UID:nogroup -e "TF_LOG=$TF_LOG" -e "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION" -v $HOME/.aws:/.aws -v $HOME/.gcp:/.gcp -v $(pwd):/input --name terraform terraform $@' > /usr/local/bin/terraform

# Add permission for running the terraform command
chmod +x /usr/local/bin/terraform

# Next, we need to make a terraform config that tells terraform what bucket to use
# to store its state
echo "\n\n\nEnter the name of your terraform state bucket"
read TERRAFORM_STATE_BUCKET
echo "\n\n\nEnter a short, unique name for this stack (no spaces, numbers, or special characters)"
read TERRAFORM_STATE_UNIQUE_KEY
cat <<EOF >  ./terraform/versions.tf
provider "archive" {}

provider "aws" {
  shared_credentials_file = "/.aws/credentials"
  region     = "us-east-1"
  profile    = "default"
}

provider "aws" {
  shared_credentials_file = "/.aws/credentials"
  alias = "frankfurt"
  region     = "eu-central-1"
}

provider "aws" {
  shared_credentials_file = "/.aws/credentials"
  alias = "sydney"
  region     = "ap-southeast-2"
}

provider "aws" {
  shared_credentials_file = "/.aws/credentials"
  alias = "canada"
  region     = "ca-central-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.49"
    }
  }
  required_version = ">= 1.0"
  backend "s3" {
    shared_credentials_file = "/.aws/credentials"
    bucket = "$TERRAFORM_STATE_BUCKET"
    key    = "demo_alpha_$TERRAFORM_STATE_UNIQUE_KEY"
    region = "us-east-1"
    profile    = "default"
  }
}
EOF
