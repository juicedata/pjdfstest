#!/bin/sh

set -o errexit
set -o nounset
set -o xtrace

apt-get update
apt-get install git nfs-common

git clone https://github.com/pjd/pjdfstest.git

pushd pjdfstest
autoreconf -ifs
./configure
make pjdfstest
popd

mount -t nfs -o vers=4,minorversion=0,noresvport $1-cgx88.cn-hongkong.nas.aliyuncs.com:/ /mnt

pushd /mnt
prove --recurse --failures /root/pjdfstest/tests | tee -a /root/test-alicloud-nas-nfs4.log
popd
