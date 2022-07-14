#!/bin/bash

function codeReview()
{
    current_path=$(pwd)
    if [[ -d $repo_dir/DeepRec ]];then
        cd $repo_dir \
        && sudo rm -rf DeepRec
    fi
    cd $repo_dir \
    && git clone $code_repo \
    && cd $repo_dir/DeepRec\
    &&git checkout $branch_name\
    &&git checkout --progress --force $commit_id\
    &&cd $current_path
}

function checkEnv()
{
    container_id=$(sudo docker ps -a | grep ut_et | awk -F " " '{print $1}')
    if [[ -n $container_id ]];then
        echo "the container ut_et has already exist"
        echo "killing ut_et container"
        sudo docker rm -f $container_di
    fi
}


function runContainer()
{
    host_path1=$(cd "$repo_dir/DeepRec" && pwd)
    host_path2=$(cd ./about_ut && pwd)

    sudo docker volume create ut_cache
    sudo docker pull $test_image_repo \
    && sudo docker run \
    -it \
    -v $host_path1:/DeepRec/ \
    -v $host_path2:/about_ut/ \
    --mount source=ut_cache,target=/root/.cache/ \
    --rm \
    --name ut_et $test_image_repo /bin/bash /about_ut/script/run.sh $currentTime
}


set -x
# 获取当前时间戳
currentTime=`date "+%Y-%m-%d-%H-%M-%S"`
repo_dir="./repo/ali_repo"
repo_dir=$(cd $repo_dir && pwd)
code_repo=$(cat ./config.properties | shyaml get-value code_repo )
branch_name=$(cat ./config.properties | shyaml get-value branch)
commit_id=$(cat ./config.properties | shyaml get-value commit )
test_image_repo=$(cat ./config.properties | gshyaml get-valuerep test_image)
log_dir="./about_ut/log/$currentTime"
if [[ ! -d $log_dir ]];then
    mkdir -p $log_dir
fi

file_path=$(cd ./about_ut/log/$currentTime && pwd)

codeReview \
&& runContainer\
&& echo "the files generated is in the directory : $file_path"
sudo docker volume rm ut_cache
