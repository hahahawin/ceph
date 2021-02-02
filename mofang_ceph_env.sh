#!/bin/bash
echo "该脚本只能在ceph脚本后使用，同时计算节点已换好内核和已正常安装魔方云"
echo "有几个魔方云计算节点"
read mofang_num
mofang_num_1=$mofang_num
a=0
echo "[mofang]" > /root/ceph_ansible/mofang_hosts
while [[ $mofang_num > "0" ]]; do
    let "a++"
    let "mofang_num--"
    echo "请输入第$a 个魔方云计算节点IP"
    read mofang$a
    echo "请输入第$a 个魔方云计算节点密码"
    read mofang_passwd$a
    eval echo "$"mofang$a"" >> /root/ceph_ansible/mofang_hosts
done
#实现到计算节点免密
rpm -q sshpass &> /dev/null || yum install sshpass -y &> /dev/null
sed -i '/Checking ask/c StrictHostKeyChecking no' /etc/ssh/ssh_config
[ -f /root/.ssh/id_rsa ] || ssh-keygen -P "" -f /root/.ssh/id_rsa &> /dev/null
b=0
while [[ $mofang_num_1 > "0" ]]; do
  let "b++"
  let "mofang_num_1--"
  mofang_ip=`eval echo "$"mofang$b""`
  mofang_passwd=`eval echo "$"mofang_passwd$b""`
  sshpass -p $mofang_passwd ssh-copy-id -i  /root/.ssh/id_rsa.pub $mofang_ip &> /dev/null
done
#在ceph主节点获取 ceph.client.admin.keyring  ceph.conf  ceph.pub 三位大哥
ansible ceph_master -m copy -a "src=/etc/ceph/ dest=/root/ceph_ansible/ceph_config/ force=yes backup=yes"
ceph_fsid=`cat /root/ceph_ansible/ceph_config/ceph.conf | grep fsid|awk -F ' ' '{print $3}'`
ceph_segment=`cat /tmp/2`
node0_ip=`cat /tmp/ceph_host_info |grep node0|awk '{print $1}'`
node1_ip=`cat /tmp/ceph_host_info |grep node1|awk '{print $1}'`
node2_ip=`cat /tmp/ceph_host_info |grep node2|awk '{print $1}'`
ceph_key=`cat /root/ceph_ansible/ceph_config/ceph.client.admin.keyring |grep key|awk '{print $3}'`
cat > /root/ceph_ansible/ceph_config/ceph.conf << EOF
[global]
fsid = $ceph_fsid
public_network = $ceph_segment
mon_initial_members = node0,node1,node2
mon_host = $node0_ip,$node1_ip,$node2_ip
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
EOF
# 生成xml绑定文件
cat > /root/ceph_ansible/secret.xml.j2 <<EOF
<secret ephemeral='no' private='no'>
  <uuid>$ceph_fsid</uuid>
  <usage type='ceph'>
        <name>client.admin secret</name>
  </usage>
</secret>
EOF
#生成热迁移文件
cat > /root/ceph_ansible/libvirtd.conf << EOF
listen_tls = 0
listen_tcp = 1
listen_addr = "0.0.0.0"
auth_tcp = "none"
EOF
#生效配置到各mofang节点
cat > /root/ceph_ansible/ceph_initenv_mofang.yml <<EOF
---
- hosts: mofang
  vars:
    max_clients: 200
  user: root
  tasks:
  - name: 计算节点安装ceph基础环境
    yum: name={{ item }} state=latest
    loop:
      - epel-release
      - ceph-common
  - name: 传送对应配置文件到计算节点
    copy: src=/root/ceph_ansible/ceph_config/ dest=/etc/ceph/  force=yes
  - name: 传送xml文件到计算节点
    template: src=/root/ceph_ansible/secret.xml.j2 dest=/etc/ceph/secret.xml
  - name: 绑定安全设置
    shell: virsh secret-define --file /etc/ceph/secret.xml
  - name: 设置安全值
    shell: virsh secret-set-value --secret $ceph_fsid --base64 $ceph_key
  - name: 开启热迁移功能
    copy: src=/root/ceph_ansible/libvirtd.conf dest=/etc/libvirt/libvirtd.conf force=yes
  - name: 重启libvirtd
    shell: systemctl restart libvirtd

EOF
ansible-playbook -i /root/ceph_ansible/mofang_hosts /root/ceph_ansible/ceph_initenv_mofang.yml