# #!/bin/bash\

# TODO  维护一个 sha256到镜像Id的映射文件


function echoColor() {
	case $1 in
	green)
		echo -e "\033[32;40m$2\033[0m"
		;;
	red)
		echo -e "\033[31;40m$2\033[0m"
		;;
	*)
		echo "Example: echo_color red string"
		;;
	esac
}


function echoLogo()
{
    echo "######################################################################"
    echo "#######################  build  pragram  #############################"
    echo "######################################################################"

}

function echoError()
{
    info=$1
    echoColor red "######################################################################"
    echoColor red "##########   $info  ##########"
    echoColor red "######################################################################"

}

# 运行容器， 指定image_repo container_name和CMD
function runDockerContrainer(){
    image_repo=$1
    container_name=$2
    command=$3
    optional=
    host_path=$(cd ./whl_build && pwd)
    
    if [[ $container_name == "whl_build" ]];then
	sudo docker volume create ut_cache
    	optional="-v  $cache_path:/root/.cache \
		 --rm"		 
    fi
    
    sudo docker run \
    -v $host_path:/whl_build $optional \
    --name $container_name \
    $image_repo \
    /bin/bash $command $currentTime
    
    if [[ $? != 0 ]];then
        echoColor red "Something wrong happened when run the container..."
        exit 1
    fi

    if [[ $container_name == "whl_build" ]];then
	    sudo docker volume rm ut_cache
    fi
}

# 将DeepRec的code调整到指定分支的指定commit上
function codeReview()
{
    current_path=$(pwd)
    if [[ -d $ali_repo_dir ]];then
        sudo rm -rf $ali_repo_dir
    fi
    cd ./whl_build/repo/ali_DeepRec/
    git clone $code_repo

    cd $current_path
    cd $ali_repo_dir

    git checkout "$branch_name"\
    && git checkout --progress --force "$commit_id"
    git_info=$(git rev-parse --short HEAD)
    echoColor red "the current commit is :$git_info"
    cd "$current_path"\
    &&echoColor red "current directory is $current"
}

# 检查当前环境是否有和要启动的容器重名的容器， 如果有就直接删掉
function checkEnv()
{
    res=$(sudo docker ps -a |grep $1)
    if [[ -n "$res" ]];then
        echoColor red "The container $1 has already exist in current environment..."
        echoColor red "going to KILL it..."
        sudo docker rm -f $1
    fi
}

# 检查存放编译好的whl的文件夹内文件的数量，如果不是仅有一个则会报错
function checkResult()
{
    declare -a res=($(ls $whl_dir$currentTime))
    num=${#res[@]}
    if [[ $num == 0 ]];then
        echoColor red "find no file in the target whl package :$whl_dir$currentTime."
        exit 1
    elif [[ $num == 1 ]];then
        echoColor green "Find one file in the target whl package :$whl_dir$currentTime."
        echoColor green "target Whl file's name is ${res[0]}" 
    else
        echoColor red "Too much file in the target Whl package :$whl_dir$currentTime."
        exit 1
    fi
}


function oss_upload()
{
    if [[ ! -f ossutil64 ]];then
        wget https://deeprec-whl.oss-cn-beijing.aliyuncs.com/ossutil64
        chmod 755 ossutil64
    fi
    
    bd_tag=-$part_date+$part_commit_id-
    whl_file=$(ls $whl_dir$currentTime)
    seg1=$(echo $whl_file | awk -F "-" '{print $1"-"$2}')
    seg2=$(echo $whl_file | awk -F "-" '{print $3"-"$4"-"$5}')
    final_name=$seg1$bd_tag$seg2

    sudo cp $whl_dir$currentTime/$whl_file $whl_dir/$final_name

    ./ossutil64 cp $whl_dir/$final_name oss://deeprec-whl/ --proxy-host http://child-prc.intel.com:913 --config-file ~/.ossutilconfig
}

# 通过编好的包来build镜像并push到镜像仓库
function build_image()
{
    temp_name=$1
    base_image_repo=$2
    class_name=${temp_name%12138*}
    checkEnv $temp_name \
    && runDockerContrainer $base_image_repo $temp_name  /whl_build/whl_package/whl_install.sh  #运行容器安装whl
    # 提交成镜像
    sudo docker commit $temp_name temp_image
    # 获取镜像id
    temp_image_id=$(sudo docker images | grep temp_image | awk -F " " '{print $3}' )
    # tag镜像并推送至仓库
    sudo docker tag $temp_image_id temp_image1 \
    && sudo docker run -itd --name temp_container1  temp_image1 /bin/bash \
    && sudo docker commit temp_container1 "cesg-prc-registry.cn-beijing.cr.aliyuncs.com/cesg-ali/$class_name:$image_tag"\
    sudo docker push "cesg-prc-registry.cn-beijing.cr.aliyuncs.com/cesg-ali/$class_name:$image_tag"  # 将镜像推送到仓库
    # 将镜像tag为latest，并推送至仓库
    if [[ $latest == 1 ]];then
        sudo docker tag $temp_image_id "cesg-prc-registry.cn-beijing.cr.aliyuncs.com/cesg-ali/$class_name:latest"\
        && sudo docker push "cesg-prc-registry.cn-beijing.cr.aliyuncs.com/cesg-ali/$class_name:latest"\
        && sudo docker rmi -f "cesg-prc-registry.cn-beijing.cr.aliyuncs.com/cesg-ali/$class_name:latest"
    fi
    # 删除刚才的临时镜像
    sudo docker rmi -f temp_image
    sudo docker rmi -f temp_image1
    # 删除刚才安装whl的容器
    sudo docker rm -f $temp_container_id 
    sudo docker rm -f temp_container1
}


# 规范化whl的名字并上传


# 主程序：
# 1. 根据指定的commit和branch来编译包
# 2. 通过编译好的whl包来Build新的执行并提交到docker仓库
function run()
{
    part_date=$(echo `date "+%Y%m%d"` | cut -c 3-8)
    part_commit_id=$(echo $commit_id | cut -c 1-7)
    image_tag=$(cat $config_file| grep image_TAG | awk -F " " '{print $2}')
    if [[ -z $image_tag ]];then
    	image_tag=$part_date-$part_commit_id
    fi
    echoColor green "image tag is : $image_tag"

    # 检查当前环境是否存在重名镜像  
    checkEnv "whl_build"
    # 调整代码到指定的branch和commit
    codeReview
    # 运行容器 编译whl包
    runDockerContrainer $build_image_repo whl_build /whl_build/build_whl.sh
    sudo rm -rf $ali_repo_dir
    checkResult \
    && oss_upload
    build_image deeprec12138 $base_image_deepRec_repo /whl_build/whl_package/whl_install.sh
    build_image deeprec-modelzoo12138 $base_image_modelzoo_repo /whl_build/whl_package/whl_install.sh
    
} 

set -x
# 配置文件地址
config_file="./../config.properties"
echo "the config file is :$config_file"
# 读编包镜像的repo
build_image_repo=$( cat $config_file | grep build_image_repo | awk -F " " '{print $2}')
# 读deepRec_modelzoo的base镜像repo
base_image_modelzoo_repo=$( cat $config_file | grep base_image_modelzoo | awk -F " " '{print $2}')
# 读deepRec的base镜像的repo
base_image_deepRec_repo=$( cat $config_file | grep base_image_deepRec | awk -F " " '{print $2}')


echoColor green "the buid image repo is :$build_image_repo"
echoColor green "the deepRec base image repo is :$base_image_deepRec_repo"
echoColor green "the modelzoo base image repo id is :$base_image_modelzoo_repo"

cache_path=./cache
mkdir $cache_path
cache_path=$(cd $cache_path && pwd)

# 阿里git code地址
ali_repo_dir="./whl_build/repo/ali_DeepRec/DeepRec/"
code_repo=$(cat $config_file | grep code_repo | awk -F " " '{print $2}')
if [[ -z $code_repo ]];then
	exit 1
fi
# ali_repo_dir="./build/whl_build/repo/changqing1_DeepRec/DeepRec"

# 存放whl的地址
whl_dir="./whl_build/whl_package/"
if [[ ! -d $whl_dir ]];then
    mkdir -p $whl_dir
fi
echoLogo
# 当前时间
currentTime=
# commit的hashcode
commit_id=$( cat $config_file | grep commit_id | awk -F " " '{print $2}')
# brach的名称
branch_name=$( cat $config_file | grep branch_name | awk -F " " '{print $2}')
# 是否需要将此image标记为latest 0不需要 1需要
latest=0

# 检查参数：
#   l:将此镜像tag为latest并push到仓库
while getopts ":l" opts;do
    case $opts in
        l)
            latest=1;;

    esac
done

# 必须指定commit_id
if [[ ! -n "$commit_id" ]];then
    echoColor red "you must specify a commit id by -c!"
    exit 1
fi

# 可以不指定branch name 默认为 main
if [[ ! -n "$branch_name" ]];then
    branch_name="main"
fi

currentTime=`date "+%Y-%m-%d-%H-%M-%S"`
# currentTime=2022-01-25-17-14-50
sudo docker pull $build_image_repo \
&& sudo docker pull $base_image_deepRec_repo \
&& sudo docker pull $base_image_modelzoo_repo \
&& run
