#!/bin/bash -ex

#Install jq, envsubst (from GNU gettext utilities) and bash-completion
sudo yum install -y jq gettext bash-completion moreutils

#Install session-manager
sudo curl --silent --location "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm

#Install kubectl and enable kubectl bash_completion
sudo curl --silent --location -o /usr/local/bin/kubectl \
   https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.11/2020-09-18/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc

#Install yq for yaml processing
echo 'yq() {
  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
}' | tee -a ~/.bashrc && source ~/.bashrc

#Install eksctl and enable eksctl bash_completion
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin
echo 'source <(eksctl completion bash)' >>~/.bashrc
source ~/.bashrc

#Verify the binaries are in the path and executable
if ! [ -x "$(command -v jq)" ] || ! [ -x "$(command -v envsubst)" ] || ! [ -x "$(command -v kubectl)" ] || ! [ -x "$(command -v eksctl)" ] || ! [ -x "$(command -v ssm-cli)" ]; then
  echo 'ERROR: tools not installed.' >&2
  exit 1
fi

#Update awscli
pip install awscli --upgrade --user