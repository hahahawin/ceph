#!/bin/bash
function ceph_destory(){
   ceph_destory_tag_more=`ls /var/lib/ceph|wc -w`
   if [ $ceph_destory_tag_more -ge "2" ]; then
       echo "该主机中存在多个集群，请手动清除，本脚本无能为力"
       exit 0
   fi
   ceph_destory_tag=`ls /var/lib/ceph`
   ansible ceph_master,ceph_slave -m shell -a  "cephadm rm-cluster --fsid $ceph_destory_tag --force"
}
function ceph_check_old(){
if [ ! -d "/var/lib/ceph" ];then
mkdir /var/lib/ceph
fi
ceph_folder=`ls /var/lib/ceph|wc -w`
if [ $ceph_folder -ge "1" ]; then
    echo "ceph集群已存在,是否清除原集群输入yes/no(确认清除将使原集群发生不可逆损毁，请谨慎选择)"
    read destory
    while [ "$destory" != "yes" ]; do
    if [ "$destory" = "no" ]; then
        echo "正在退出安装。。。"
        exit 0
    fi
    echo "是否摧毁原集群， 输入yes/no"
    read destory
    done
    ceph_destory 
fi    
}
echo -e "\n"
echo -e "\033[31m ***********************************************************************************************************\033[0m"
echo -e "\033[31m *     本脚本只能在centos7或者centos8下运行，如在其他系统运行会发生致命错误,安装前请确保全集群网络正常     *\033[0m"
echo -e "\033[31m ***********************************************************************************************************\033[0m"
echo -e "\n"
#如果全集群没有网 先搭建网桥
#判断是否是centos7或者8系统
sysvertion=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
if [[ $sysvertion = "7" ]] || [[ $sysvertion = "8" ]]; then
   echo -e "\033[32m 系统符合要求，开始部署。。。\033[0m"
   echo -e "\n"
else
   echo -e "\033[31m 系统不符合要求，退出中。。。\033[0m"
   exit 0
fi
rpm -q epel-release &> /dev/null || yum install epel-release -y &> /dev/null
rpm -q wget &> /dev/null || yum install wget -y &> /dev/null
rpm -q python3 &> /dev/null || yum install python3 -y &> /dev/null
#判断ansible是否存在，不存在就安装
ansible_status=`rpm -qa|grep ansible|wc -l`
if [ $ansible_status -eq 0 ]; then
   yum install -y ansible
fi
#客户输入配置信息，用于生成ansible yml
[ -d /root/ceph_ansible ] || mkdir /root/ceph_ansible
echo -e "\033[31m 全局部分\033[0m"
echo "******************************"
echo "* 要安装的ceph一共有几台主机 *"
echo "******************************"
read ceph_number
ceph_number_Secret=$ceph_number
ceph_number_hosts=$ceph_number
ceph_number_mon=$ceph_number
ceph_number_info=$ceph_number
echo "内网IP地址 内网网卡 主机ROOT密码" > /etc/ansible/info_tmp
echo -e "\n\n"
echo "**********************"
echo "* 请输入ceph内网网段 *"
echo "**********************" 
read ceph_segment
echo -e "\n\n"
echo -e "\033[31m CEPH主节点部分\033[0m"
echo "******************************"
echo "* 请输入ceph主节点内网ip地址 *"
echo "******************************"
read ceph_master_ip
echo -e "\n\n"
echo "************************"
echo "* 请输入主节点root密码 *"
echo "************************"
read ceph_master_password
echo -e "\n\n"
echo "**************************"
echo "* 请输入主节点内网网卡名 *"
echo "**************************"
read ceph_master_card
echo -e "\n\n"
echo "$ceph_master_ip $ceph_master_card $ceph_master_password" >> /etc/ansible/info_tmp 
a=0
echo "" > /etc/ansible/hosts_tmp #1
sed -i '1d' /etc/ansible/hosts_tmp #4 #清空上一句产生的空行
echo -e "\033[31m CEPG子节点部分\033[0m"
while [[ $ceph_number > "1" ]]; do
    let "a++"
    let "ceph_number--"
    echo "*********************************"
    echo "* 请输入ceph子节点$a 内网ip地址 *"
    echo "*********************************"
    read ceph_slave_ip$a
    echo -e "\n\n"
    echo "****************************"
    echo "* 请输入当前子节点root密码 *"
    echo "****************************"
    read ceph_slave_password$a
    echo -e "\n\n"
    echo "*****************************"
    echo "* 请输入子节点$a 内网网卡名 *"
    echo "*****************************" 
    read ceph_slave_card
    echo -e "\n\n"
    eval echo "$"ceph_slave_ip$a hostname=node$a ceph_card=$ceph_slave_card"" >> /etc/ansible/hosts_tmp #2
    eval echo "$"ceph_slave_ip$a $ceph_slave_card "$"ceph_slave_password$a"""" >> /etc/ansible/info_tmp
done
echo -e "\033[31m 请认真确认下面的信息，如果信息有误将导致部署失败\033[0m"
echo "******************************************************************************"
echo ""
cat /etc/ansible/info_tmp |awk ' {printf "%-25s %-25s %-10s\n",$1,$2,$3}'
echo ""
echo "ceph节点一共有:$ceph_number_info" 
echo "ceph网段是:$ceph_segment"
echo ""
echo "*******************************************************************************"
echo "请确认上面的信息正确性 正确请输入yes 退出安装请输入no"
read asd
while [ "$asd" != "yes" ]; do
  if [ "$asd" = "no" ]; then
        exit 0
  fi
  echo "请确认上面的信息正确性 输入yes/no"
  read asd
done
#部署主机到集群各节点免密 实现ansible可用
:<< 提示
rpm -q sshpass &> /dev/null || yum install sshpass -y &> /dev/null #判断sshpass是否安装 没安装就安装它
sed -i '/Checking ask/c StrictHostKeyChecking no' /etc/ssh/ssh_config #取消主机密钥检查
[ -f /root/.ssh/id_rsa ] || ssh-keygen -P "" -f /root/.ssh/id_rsa &> /dev/null#判断本机密钥是否存在 不存在就创建
sshpass -p $mima ssh-copy-id -i  /root/.ssh/id_rsa.pub $ip #复制密钥到对应服务器
提示
rpm -q sshpass &> /dev/null || yum install sshpass -y &> /dev/null
sed -i '/Checking ask/c StrictHostKeyChecking no' /etc/ssh/ssh_config
[ -f /root/.ssh/id_rsa ] || ssh-keygen -P "" -f /root/.ssh/id_rsa &> /dev/null
sshpass -p $ceph_master_password ssh-copy-id -i  /root/.ssh/id_rsa.pub $ceph_master_ip &> /dev/null
b=0
while [[ $ceph_number_Secret > "1" ]]; do
  let "b++"
  let "ceph_number_Secret--"
  ceph_slave_ip_Secret=`eval echo "$"ceph_slave_ip$b""`
  ceph_slave_password_Secret=`eval echo "$"ceph_slave_password$b""`
  sshpass -p $ceph_slave_password_Secret ssh-copy-id -i  /root/.ssh/id_rsa.pub $ceph_slave_ip_Secret &> /dev/null
done
#定义ansible检测各节点主机外网联通性
function ceph_check_network(){
#ceph_network_status=`ansible ceph_master,ceph_slave -m shell -a "curl -I -m 60 -o /dev/null -s -w %{http_code} https://mirrors.aliyun.com/ceph/rpm-15.2.6/el7/noarch/ceph-release-1-1.el7.noarch.rpm"`
ceph_network_status=`ansible ceph_master,ceph_slave -m shell -a "ping -W 2 -c 2 mirrors.aliyun.com"`
echo "检查ceph各节点网络状态"
echo "$ceph_network_status"
ceph_network_status_check=`echo "$ceph_network_status"|grep -E "100% packet loss"|"service not knownnon"`
if [ -n "$ceph_network_status_check" ];then
    echo -e "\033[31m ceph节点无法访问外网或ceph镜像库，请检查网络！\033[0m"
    echo -e "\n"
    echo -e "\033[31m 安装退出中。。。\033[0m"
    exit 0
fi
}
#初始化master主机环境
##生成ansible hosts文件

cat > /etc/ansible/hosts <<EOF
[ceph:children]
ceph_master
ceph_slave
[ceph_master]
$ceph_master_ip hostname=node0
[ceph_slave]
EOF
cat /etc/ansible/hosts_tmp >>/etc/ansible/hosts #3 #1234部分生成了hosts_tmp eval可以应对变量嵌套 例如eval echo "$"ymd$i""
ceph_check_network #检查集群网络
##生成集群hosts文件
cat > /root/ceph_ansible/hosts.j2 <<EOF
127.0.0.1   localhost localhost.localdomain
$ceph_master_ip node0
EOF
c=0
while [[ $ceph_number_hosts > "1" ]]; do
  let "c++"
  let "ceph_number_hosts--"
  ceph_slave_ip_hosts=`eval echo "$"ceph_slave_ip$c""`
  echo "$ceph_slave_ip_hosts node$c" >> /root/ceph_ansible/hosts.j2
done
## 获取cephadm安装脚本
wget -O /root/ceph_ansible/cephadm_15.2.8.j2 https://liquanbing.oss-cn-chengdu.aliyuncs.com/ceph/cephadm_15.2.8
##生成podman国内加速文件
cat > /root/ceph_ansible/registries.j2 <<EOF
unqualified-search-registries = ["docker.io"]

[[registry]]

prefix = "docker.io"

location = "docker.mirrors.ustc.edu.cn"
#清华大学加速docker镜像仓库
EOF
##生成时间chrony主节点同步文件
cat > /root/ceph_ansible/chrony_master.j2 <<EOF
server cn.pool.ntp.org iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
allow 0.0.0.0/0
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
noclientlog
logchange 0.5
logdir /var/log/chrony
EOF
##生成时间chrony子节点同步文件
cat > /root/ceph_ansible/chrony_slave.j2 << EOF
server $ceph_master_ip iburst
EOF
##生成执行ansible主节点初始化yml
echo "开始初始化主节点环境"
cat > /root/ceph_ansible/ceph_initenv_master.yml <<EOF
---
- hosts: ceph_master
  vars:
    max_clients: 200
  user: root
  tasks:
  - name: 安装epel源
    yum: pkg=epel-release  state=latest
  - name: 传送cephadm安装脚本
    copy: src=/root/ceph_ansible/cephadm_15.2.8.j2 dest=/tmp/cephadm_15.2.8
  - name: 安装ceph源
    file: dest=/tmp/cephadm_15.2.8 mode=777
  - name: 添加15.2.8的yum源
    shell: /tmp/cephadm_15.2.8 add-repo --release octopus
  - name: 安装podman
    yum: pkg=podman state=latest
  - name: 初始化cephadm
    shell: /tmp/cephadm_15.2.8 install
  - name: 安装gdisk
    yum: pkg=gdisk state=latest
  - name: 打开firewalld
    service: name=firewalld state=started enabled=yes
  - name: 添加网卡放行防火墙规则
    shell: firewall-cmd --zone=trusted --add-interface=$ceph_master_card --permanent
  - name: 添加时间同步端口防火墙规则
    shell: firewall-cmd --zone=public --add-port=123/udp --permanent && firewall-cmd --reload
  - name: 临时关闭selinux
    selinux: state=disabled
  - name: 永久关闭selinux
    shell: sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  - name: 永久关闭selinux
    shell: sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
  - name: 更改podman镜像库为清华大学
    template: src=/root/ceph_ansible/registries.j2 dest=/etc/containers/registries.conf
  - name: 更改host列表
    template: src=/root/ceph_ansible/hosts.j2 dest=/etc/hosts
  - name: 更改主机名
    raw: "echo {{hostname|quote}} > /etc/hostname"
  - name: 生效主机名
    shell: hostname {{hostname|quote}}
  - name: 安装时间同步服务
    yum: pkg=chrony state=latest
  - name: 配置时间同步服务
    template: src=/root/ceph_ansible/chrony_master.j2 dest=/etc/chrony.conf
  - name: 重启时间同步服务
    shell: systemctl restart chronyd && systemctl enable chronyd
EOF
ansible-playbook -i /etc/ansible/hosts /root/ceph_ansible/ceph_initenv_master.yml
##生成执行ansible主节点初始化yml
echo "开始初始化子节点环境"
cat > /root/ceph_ansible/ceph_initenv_slave.yml <<EOF
---
- hosts: ceph_slave
  vars:
    max_clients: 200
  user: root
  tasks:
  - name: 安装epel源
    yum: pkg=epel-release  state=latest
  - name: 传送cephadm安装脚本
    copy: src=/root/ceph_ansible/cephadm_15.2.8.j2 dest=/tmp/cephadm_15.2.8
  - name: 安装ceph源
    file: dest=/tmp/cephadm_15.2.8 mode=777
  - name: 添加15.2.8的yum源
    shell: /tmp/cephadm_15.2.8 add-repo --release octopus
  - name: 安装podman
    yum: pkg=podman state=latest
  - name: 初始化cephadm
    shell: /tmp/cephadm_15.2.8 install
  - name: 安装gdisk
    yum: pkg=gdisk state=latest
  - name: 打开firewalld
    service: name=firewalld state=started enabled=yes
  - name: 添加网卡放行防火墙规则
    shell: firewall-cmd --zone=trusted --add-interface={{ceph_card}} --permanent
  - name: 添加时间同步端口防火墙规则
    shell: firewall-cmd --zone=public --add-port=123/udp --permanent && firewall-cmd --reload
  - name: 临时关闭selinux
    selinux: state=disabled
  - name: 永久关闭selinux
    shell: sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  - name: 永久关闭selinux
    shell: sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
  - name: 更改podman镜像库为清华大学
    template: src=/root/ceph_ansible/registries.j2 dest=/etc/containers/registries.conf
  - name: 更改host列表
    template: src=/root/ceph_ansible/hosts.j2 dest=/etc/hosts
  - name: 更改主机名
    raw: "echo {{hostname|quote}} > /etc/hostname"
  - name: 生效主机名
    shell: hostname {{hostname|quote}}
  - name: 安装时间同步服务
    yum: pkg=chrony state=latest
  - name: 配置时间同步服务
    template: src=/root/ceph_ansible/chrony_slave.j2 dest=/etc/chrony.conf
  - name: 重启时间同步服务
    shell: systemctl restart chronyd && systemctl enable chronyd
EOF
ansible-playbook -i /etc/ansible/hosts /root/ceph_ansible/ceph_initenv_slave.yml
ceph_check_old
echo "开始初始化集群环境"
if [ $(( $ceph_number_mon % 2 )) = 0 ]; then #mon的数量保证奇数
        let "ceph_number_mon--"
fi
ansible ceph_master -m shell -a "cat /etc/hosts" > /tmp/ceph_host_info
cat > /root/ceph_ansible/ceph_initenv.yml <<EOF
---
- hosts: ceph_master
  vars:
    max_clients: 200
  user: root
  tasks:
  - name: 创建ceph配置目录
    file: path=/etc/ceph state=directory
  - name: 创建ceph主节点
    shell: cephadm bootstrap --mon-ip $ceph_master_ip > /root/ceph_dashboard.log 2>&1
  - name: 添加主节点
    shell: ssh-copy-id -f -i /etc/ceph/ceph.pub root@node0 && cephadm shell -- ceph orch host add node0
  - name: 添加其余各节点
    shell: ssh-copy-id -f -i /etc/ceph/ceph.pub root@{{hostname|quote}} && cephadm shell -- ceph orch host add {{hostname|quote}}
  - name: 配置公共网络
    shell: cephadm shell -- ceph config set mon public_network $ceph_segment
  - name: 指定mon数量
    shell: cephadm shell -- ceph orch apply mon $ceph_number_mon
EOF
ansible-playbook -i /etc/ansible/hosts /root/ceph_ansible/ceph_initenv.yml
echo "恭喜部署完成"
echo "请访问dashbrod初始化ceph pool，前端配置如下（如果信息为空，证明节点部署失败，请重跑脚本）"
ansible ceph_master -m shell -a "cat /root/ceph_dashboard.log|sed -n "/Dashboard/,/Password/p""
echo "请将如下内容加入访问dashbrod——web的host文件，否则可能无法正常访问服务"
echo -e "\n"
cat /tmp/ceph_host_info |sed '1,2d'
echo -e "\n"




