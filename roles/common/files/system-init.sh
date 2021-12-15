#!/bin/bash

# 1. close selinux
sed -i '/^SELINUX=.*/c SELINUX=disabled' /etc/selinux/config
setenforce 0

# 2. close firewall
systemctl stop firewalld
systemctl disable firewalld

# 3. modify timezone
timedatectl set-timezone Asia/Shanghai
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 4. tcp connect
cat >/etc/security/limits.conf <<EOF
* soft nproc  65535
* hard nproc  65535
* soft nofile 65535
* hard nofile 65535
EOF

# 5. Process optimization
cat >/etc/security/limits.d/20-nproc.conf <<EOF
* soft nproc unlimited
* hard nproc unlimited
EOF

# 6. Update kernel param
/usr/bin/cp -f /etc/sysctl.conf /etc/sysctl.conf.bak
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
cat >/etc/sysctl.conf <<EOF
fs.file-max=1000000
vm.swappiness = 0
vm.max_map_count = 262144
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 262144
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_fin_timeout = 1
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
EOF

/usr/sbin/sysctl -p

## 7. histroy 上下键调出历史命令
cat <<EOF >/etc/profile.d/bash_history.sh
if [ -t 1 ];then
    # standard output is a tty
    # do interactive initialization
    bind '"\x1b\x5b\x41":history-search-backward'
    bind '"\x1b\x5b\x42":history-search-forward'
fi
EOF

## 8. 配置vim
mkdir -p /etc/vim
cat <<EOF >/etc/vim/vimrc.local
set fencs=utf-8,usc-bom,euc-jp,gb18030,gbk,gb2312,cp936
syntax on
set paste
set nu
set tabstop=4
set list
set listchars=eol:¶,tab:»\ ,trail:~,nbsp:·
EOF

## 9. 关闭swapoff分区
swapoff -a

## 10. 配置kubectl命令补全
# source /usr/share/bash-completion/bash_completion
# source <(kubectl completion bash)
# echo "source <(kubectl completion bash)" >>~/.bashrc

sleep 3