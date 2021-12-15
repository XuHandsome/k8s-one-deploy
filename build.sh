#!/bin/bash
shopt -s extglob
ver=1.0
buildver="$(date '+%Y.%m.%d').$(git log --format="%h" -n 1)"

clean() {
    echo "clean ..."
    rm -fr k8s-one-deploy*
}

# clean
clean
# build
echo "prepare source ..."
if ! git lfs pull; then
    echo "error: git lfs pull failed."
    exit 1
fi

mkdir k8s-one-deploy
mkdir k8s-one-deploy/logs
cp -rp *.sh k8s-one-deploy
cp -rp *.template k8s-one-deploy
cp -rp roles k8s-one-deploy
cp -rp yum k8s-one-deploy
cp -rp ansible.cfg k8s-one-deploy
chmod +x k8s-one-deploy/*.sh

# clean useless files
find ./ -name .DS_Store -exec rm -rf '{}' \;
find ./k8s-one-deploy -name ".git*" -exec rm -rf '{}' \;
rm -fr k8s-one-deploy/{build.sh,.version,readme.md,k8s-one-deploy,.git*} k8s-one-deploy/data/*
echo "build version: $buildver"
echo "$buildver" >k8s-one-deploy/.version

cp -rp packages k8s-one-deploy

# sudo chown root.root -R k8s-one-deploy

if ! COPYFILE_DISABLE=1 gtar czf k8s-one-deploy-${ver}.x86_64.tar.gz k8s-one-deploy; then
    echo "error: create package failed."
    clean
    exit 1
fi

# sudo chown root.root -R k8s-one-deploy-${ver}.x86_64.tar.gz

echo "post clean ..."
rm -fr k8s-one-deploy
echo 'done.'
