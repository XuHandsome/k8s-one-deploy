#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$PATH
base=$(cd $(dirname $0) && pwd)
hosts=$base/hosts

red() {
    echo -e "\033[31m $* \033[0m"
}

green() {
    echo -e "\033[32m $* \033[0m"
}

cd $base || {
    red "error: cannot cd into $base"
    exit 1
}

[ -d $base ] || {
    red "error: deploy base dir $base not exists."
    exit 1
}

deploy_start() {
    green "Deploy $1 services ..."
    sleep 1
}

deploy_end() {
    local retval=$1
    if [ $retval -eq 0 ]; then
        green "Deploy success."
        echo
        return
    fi
    red "Deploy failed."
    echo
    exit 1
}
check_end() {
    local retval=$1
    if [ $retval -eq 0 ]; then
        green "Health check success."
        green "----------------------------------------------------------------------------"
        return
    fi
    red "Health check failed."
    red "----------------------------------------------------------------------------"
}

get_config() {
    local key="$1"
    if [ -f $hosts ]; then
        grep "^$key=" $hosts | tail -1 | awk -F'=' '{print $2}' | sed "s/^'//;s/'$//" | sed 's/^"//;s/"$//'
    else
        return 1
    fi
}

check_config() {
    # check master ip is ansible host
    if [ ! -f $hosts ]; then
        red "error: no such hosts file"
        exit 1
    fi
    local master_ip=$(grep '^master ' $hosts | sort -V | tail -1 | awk -F'=' '{print $2}')
    [[ -n "$master_ip" ]] || {
        red "error: failed to get master ip"
        exit 1
    }
    ip -o a | grep -wq "$master_ip"
    [ $? -ne 0 ] && {
        red "error: must set this node as master"
        exit 1
    }
    # check ssh port is listen
    local sshport=$(get_config ansible_ssh_port)
    sshportlisten=false
    for pid in $(ps aux | grep '/usr/sbin/sshd' | grep -v grep | awk '{print $2}'); do
        if ss -lnp | grep -w pid=$pid | grep -q ":${sshport}\s"; then
            sshportlisten=true
            break
        fi
    done
    if [[ $sshportlisten = false ]]; then
        red "error: ansible_ssh_port $sshport is not in listen state on this node."
        exit 1
    else
        green "ssh port ok"
    fi
}

clean_yum() {
    cd $base
    createrepo --update yum
    yum clean all >/dev/null 2>&1
}

deploy_init() {
    check_config
    ##配置本地repo源
    [ -d $base/yum ] || {
        echo "error: cannot find yum dir: $base/yum"
        exit 1
    }

    [ ! -f /etc/yum.repos.d/CentOS-Base.repo ] || {
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    }
    [ ! -f /etc/yum.repos.d/epel.repo ] || {
        mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
    }

    if ! [ -x /usr/bin/createrepo ]; then
        green "installing createrepo ..."
        yum -y install createrepo >/dev/null 2>&1
        if ! [ -x /usr/bin/createrepo ]; then
            zlib_pkg=$(find -L $base/yum/ -name zlib-[0-9]* | sort -V | tail -1)
            createrepo_pkg=$(find -L $base/yum/ -name createrepo-[0-9]* | sort -V | tail -1)
            deltarpm_pkg=$(find -L $base/yum/ -name deltarpm-[0-9]* | sort -V | tail -1)
            libxml2_pkg=$(find -L $base/yum/ -name libxml2-[0-9]* | sort -V | tail -1)
            libxml2_python_pkg=$(find -L $base/yum/ -name libxml2-python-[0-9]* | sort -V | tail -1)
            python_deltarpm_pkg=$(find -L $base/yum/ -name python-deltarpm-[0-9]* | sort -V | tail -1)
            sudo yum -y localinstall $zlib_pkg $createrepo_pkg $deltarpm_pkg $libxml2_pkg $libxml2_python_pkg $python_deltarpm_pkg >/dev/null
        fi
    fi
    [ -x /usr/bin/createrepo ] || {
        red "install createrepo package failed"
        exit 1
    }
    green "updating yum repo metadata ..."
    createrepo --update $base/yum/ >/dev/null

    green "preparing install env ..."
    cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=kubernetes
baseurl=file://${base}/yum/
enabled=1
gpgcheck=0
EOF
    yum clean all >/dev/null
    yum makecache >/dev/null

    [ -x /usr/bin/expect ] || {
        rpmpath=$base/yum/
        [ -d $rpmpath ] || rpmpath=$base
        expect_pkg=$(find -L $rpmpath -name 'expect-[0-9]*.rpm' 2>/dev/null | sort -V | tail -1)
        tcl_pkg=$(find -L $rpmpath -name 'tcl-[0-9]*.rpm' 2>/dev/null | sort -V | tail -1)
        if [[ -n "$expect_pkg" ]] && [[ -n $tcl_pkg ]]; then
            yum localinstall -y $expect_pkg $tcl_pkg >/dev/null
        else
            yum -y install expect &>>/dev/null
        fi
        if ! [ -x /usr/bin/expect ]; then
            red "install expect failed"
            exit 1
        fi
    }

    # 移除自带无效rsync并重新安装
    yum remove -y rsync >/dev/null
    rpmpath=$base/yum/
    [ -d $rpmpath ] || rpmpath=$base
    rsync_pkg=$(find -L $rpmpath -name 'rsync-[0-9]*.rpm' 2>/dev/null | sort -V | tail -1)
    if [[ -n "$rsync_pkg" ]]; then
        yum localinstall -y $rsync_pkg >/dev/null
    else
        yum -y install rsync &>>/dev/null
    fi
    if ! [ -x /usr/bin/rsync ]; then
        red "install expect failed"
        exit 1
    fi

    for pkg in net-tools vim telnet zip unzip sshpass bzip2; do
        if ! rpm -q $pkg >/dev/null 2>&1; then
            yum -y --disablerepo="*" --enablerepo=kubernetes install $pkg >/dev/null
        fi
    done

    if ! rpm -q openresty >/dev/null 2>&1; then
        yum -y --disablerepo="*" --enablerepo=kubernetes install openresty >/dev/null
    fi
    [ -x /usr/local/openresty/nginx/sbin/nginx ] || {
        red 'install openresty failed'
        exit 1
    }

    cat >/usr/local/openresty/nginx/conf/nginx.conf <<"EOF"
#user  nobody;
worker_processes  4;
worker_rlimit_nofile 60000;
error_log /dev/null crit;
events {
    worker_connections  10240;
}

#pid        logs/nginx.pid;

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  logs/access.log main;

    sendfile        on;
    keepalive_timeout  65;
    client_max_body_size 1024m;
    server_tokens off;

    #gzip  on;
    ssi on;
    ssi_silent_errors on;
    include conf.d/*.conf;
}
EOF
    [ -d /usr/local/openresty/nginx/conf/conf.d ] || mkdir /usr/local/openresty/nginx/conf/conf.d
    cat >/usr/local/openresty/nginx/conf/conf.d/kubernetes-yum.conf <<EOF
server {
    listen  9527;
    server_name  localhost;
    root $base/yum;
    access_log  logs/kubernetes_yum_access.log;

    location / {
        autoindex off;
    }
}
EOF

    service openresty restart 2>/dev/null
    systemctl enable openresty >/dev/null 2>&1

    cd $base
    # 安装ansible2.8.0
    if [[ ! -d ansible ]]; then
        unzip -q packages/ansible-v2.8.0-py2.zip
        if [[ ! -d ansible-playbook ]]; then
            ln -s ansible ansible-playbook
        fi
    fi
    green "ansible-playbook 2.8.0 installed."

    user=$(get_config ansible_ssh_user)
    if [ $user != 'root' ]; then
        sed -i "s#root#${user}#g" roles/elasticsearch.yml
        sed -i "s#root#${user}#g" roles/mysql.yml
        green "remote ssh user is $user"
    else
        green "remote ssh user is root"
    fi
    python ansible-playbook -i $hosts roles/init.yml
    green 'init done.'
}

deploy_k8s() {
    python ansible-playbook -i $hosts roles/registry.yml
    python ansible-playbook -i $hosts roles/k8s.yml
}

comp_update() {
    local comp=$1
    shift
    local args="$@"
    python ansible-playbook -i $hosts roles/${comp}.yml $args
}

update-k8s() {
    comp_update k8s
}

update-registry() {
    comp_update registry
}

case $1 in
init)
    deploy_init
    ;;
deploy)
    deploy_k8s
    ;;
clean-yum)
    clean_yum
    ;;
update-*)
    $1
    ;;
*)
    echo "usage: $0 option"
    echo "options:"
    echo "-----------------------------------------------------"
    echo "init              init system"
    echo "deploy            one install kubernetes"
    echo "update-k8s        update k8s services"
    echo "update-registry   update image registry"
    exit
    ;;
esac
