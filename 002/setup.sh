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
