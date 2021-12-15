# Kubernetes一键安装
基于ansible的离线环境一键部署kubernetes1.18.20 三节点/单机 集群
部署环境要求:
1. Centos7.9 minimall
2. 必须单独挂载/data数据目录

## 一、构建
环境要求: 类unix终端环境即可
```bash
git clone https://gitee.com/Xuhandsome/k8s-one-deploy.git
cd k8s-one-deploy
./build.sh
```
得到部署包`k8s-one-deploy-1.0.x86_64.tar.gz`,上传至服务器部署机/data目录并解压

## 二、、配置文件
1. 复制一个配置文件
```bash
cd /data/k8s-one-deploy;
cp hosts.template hosts
```

2. 编辑hosts配置文件,自行修改三节点的ip地址,如果是单机部署,仅保留master行即可,worker*行删除
```bash
[all]
master ansible_host=192.168.96.146
worker01 ansible_host=192.168.96.147
worker02 ansible_host=192.168.96.148

[all:vars]
ansible_ssh_user='root'
ansible_ssh_port=22
ansible_ssh_pass='password'

# docker服务数据目录，尽量放在容量较大的数据盘中
docker_path=/data/docker
# docker0网段设置，可自定义避免与部署网络环境冲突
docker0_net="192.168.250.1/24"


# k8s配置
serviceSubnet=10.24.0.0/16
podSubnet=10.23.0.0/16
```

## 四、执行安装
1. 执行初始化脚本
    ```bash
    cd /data/kubernetes-local-deploy;
    ./deploy.sh init
    ```
2. 执行安装脚本
    ```bash
    cd /data/kubernetes-local-deploy;
    ./deploy.sh deploy
    ```

整体执行时间10分钟左右