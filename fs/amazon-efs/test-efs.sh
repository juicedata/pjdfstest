#!/bin/sh

set -o errexit
set -o nounset
set -o xtrace

sudo yum install -y autoconf automake gcc git

git clone https://github.com/pjd/pjdfstest.git

pushd pjdfstest
autoreconf -ifs
./configure
make pjdfstest
popd

sudo yum install -y amazon-efs-utils
sudo mkdir efs
sudo mount -t efs $1:/ efs

pushd efs
sudo prove --recurse --failures ../pjdfstest/tests | tee -a ~/pjdfstest-amazon-efs.log
popd
