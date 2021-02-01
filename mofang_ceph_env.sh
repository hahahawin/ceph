#!/bin/bash
cat > /root/ceph_ansible/ceph_initenv.yml <<EOF
---
- hosts: mofang
  vars:
    max_clients: 200
  user: root
  tasks:
  - name: 魔方安装ceph基础环境
    yum: name={{ item }} state=latest
    loop:
      - epel-release
      - ceph-common
  - name:
EOF



ansible mofang -m copy -a src=/etc/ceph/