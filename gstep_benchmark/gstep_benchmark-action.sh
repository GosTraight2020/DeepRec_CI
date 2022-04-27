# 将要在容器中执行的命令归档
function make_script()
{
    IFS_old=$IFS
    IFS=$'\n'
    make_single_script deeprec_bf16 $deeprec_bf16_script
    make_single_script deeprec_fp32 $deeprec_fp32_script
    make_single_script tf_fp32 $tf_fp32_script
    IFS=$IFS_old
}

function make_single_script()
{
    catg=$1
    script=$2
    # 记录运行的命令脚本
    bf16_para=
    [[ ! -d $(dirname $script) ]] && mkdir -p $(dirname $script)

    echo "model_list=\$1" >>$script
    [[ $catg != "tf_fp32" ]] &&echo " " >> $script &&  echo "$env_var" >> $script
    echo " " >> $script && echo "bash  /benchmark_result/record/tool/check_model.sh $catg $currentTime \"\${model_list[*]}\"" >>$script
    [[ $catg == "deeprec_bf16" ]] && bf16_para="--bf16"


    for line in $(cat $config_file | grep CMD | grep $cat] )
    do
        command=$(echo "$line" | awk -F ":" '{print $2}'| awk -F "|" '{print $1}')
        paras=$(echo "$line" | awk -F ":" '{print $2}' | awk -F "|" '{print $2}')
        log_tag=$(echo $paras| sed 's/ /_/g')
        model_name=$(echo "${line}" | awk -F ":" '{print $1}' | awk -F " " '{print $2}' | awk -F "_" '{print $1}')
        echo "echo 'testing $model_name of $catg $paras.......'" >> $script
        echo "cd /root/modelzoo/$model_name/" >> $script
        if [[ ! -d  $checkpoint_dir$currentTime/${model_name,,}_script$$log_tag ]];then
                sudo mkdir -p $checkpoint_dir$currentTime/${model_name,,}_$script$log_tag
        fi
        if [[  $weekly != 'true' ]];then
            newline="LD_PRELOAD=/root/modelzoo/libjemalloc.so.2.5.1 $command $paras --steps 3000 --no_eval  $bf16_para --checkpoint $checkpoint_dir$currentTime/${model_name,,}_$catg$log_tag  >$log_dir$currentTime/${model_name,,}_$catg$log_tag.log 2>&1"
        else
            newline="LD_PRELOAD=/root/modelzoo/libjemalloc.so.2.5.1 $command --timeline 1000 --steps 3000 --no_eval  $bf16_para --checkpoint $checkpoint_dir$currentTime/${model_name,,}_$catg  >$log_dir$currentTime/${model_name,,}_$catg.log 2>&1"
        fi
        echo $newline >> $script
    done
}



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


function runSingleContainer()
{
    image_repo=$1
    script_name=$2
    container_name=$(echo $2 | awk -F "." '{print $1}')
    [[ -z $cpus ]] && optional=""
    [[ -n $cpus ]] && optional="--cpuset-cpus $cpus"
    model_list=($(cat $config_file | grep CMD | grep $container_name | awk -F ':' '{print $1}' | awk -F ' ' '{print $2}' | awk -F '_' '{print $1}'))
    host_path=$(cd benchmark_result && pwd)

    sudo docker run --name $container_name\
                    $optional  \
                    --rm \
                    -v $host_path:/benchmark_result/\
                    $image_repo /bin/bash /benchmark_result/record/script/$currentTime/$script_name "${model_list[*]}"
}


function runContainers()
{  
    [[ -n $deeprec_bf16_CMD ]] && runSingleContainer $deeprec_test_image deeprec_bf16.sh        
    [[ -n $deeprec_fp32_CMD ]] && runSingleContainer $deeprec_test_image deeprec_fp32.sh       
    [[ -n $tf_fp32_CMD ]] && runSingleContainer $tf_test_image tf_fp32.sh   
    echo "all container finished"
}

function checkEnv()
{   
    status1=$(sudo docker ps -a | grep deeprec_bf16)
    status2=$(sudo docker ps -a | grep deeprec_fp32)
    status3=$(sudo docker ps -a | grep tf_fp32)
    [[  -n $status1 ]] && sudo docker rm -f deeprec_bf16
    [[  -n $status2 ]] && sudo docker rm -f deeprec_fp32
    [[  -n $status3 ]] && sudo docker rm -f tf_fp32
    echo "check Env Over"
}

function push_to_git()
{
	dp_tag=$(echo $deeprec_test_image | awk -F ":" '{print $2}')
	tf_tag=$(echo $deeprec_test_image | awk -F ":" '{print $2}')
	[[ -z $tf_fp32_CMD ]] && tf_tag='None'
	[[ -z $deeprec_bf16_CMD ]] && [[ -z $deeprec_fp32_CMD ]] && dp_tag='None'
	current_path=$(pwd)
	cd $pointcheck_dir/$currentTime/\
	&& zip -r ${currentTime}-deeprec-${dp_tag}-tf-${tf_tag}.zip ./*
	git add $pointcheck_dir/$currentTime/${currentTime}-deeprec-${dp_tag}-tf-${tf_tag}.zip \
	&& git add $gol_dir/$currentTime/* \&&
	cd $current_path
	if [[ $weekly == 'true' ]];then
		git commit -m "[Regression Benchmark] Add the checkpoint and log directory of $currentTime, and the DeepRec image is $dp_tag  the TF image is $tf_tag" 
	else
		git commit -m "[Benchmark] Add the checkpoint and log directory of $currentTime, and the DeepRec image is $dp_tag  the TF image is $tf_tag" 
	fi
	git push
}	

function upOss()
{
	pwd
	test_image=$( cat $config_file |grep deeprec_test_image | awk -F " " '{print $2}' | awk -F ":" '{print $2}' )
	cd $gol_dir/$currentTime
	pwd
	cur_Time=$( echo "$currentTime" | awk -F "-" '{print$1$2$3}' )
	echo "cur-Time:$cur_Time"
	zipName="log-$test_image-$cur_Time.zip"
	echo "zipName:$zipName"
	sudo zip -r $zipName ./*
	cd ..
	cd ..
	pwd
	cd $pointcheck_dir/$currentTime
        zipNameT="timeline-$test_image-$cur_Time.zip"
        sudo zip -r $zipNameT ./*
	cd ..
	cd ..
	echo "connecting ossutil64"
	if [[ ! -f ossutil64 ]];then
	wget https://deeprec-whl.oss-cn-beijing.aliyuncs.com/ossutil64
	chmod 755 ossutil64
        fi
	if [[ -f ossutil64 ]];then
		./ossutil64 cp $gol_dir/$currentTime/$zipName oss://deeprec-log/ --config-file /home/zekun/.ossutilconfig
		OssHtml="https://deeprec-log.oss-cn-beijing.aliyuncs.com/$zipName"
		echo "Log OSS successful:$OssHtml"
		./ossutil64 cp $pointcheck_dir/$currentTime/$zipNameT oss://deeprec-log/timeline/ --config-file /home/zekun/.ossutilconfig
		OssHtml="https://deeprec-log.oss-cn-beijing.aliyuncs.com/$zipNameT"
		echo "Timeline OSS successful:$OssHtml"	
	fi

}

currentTime=`date "+%Y-%m-%d-%H-%M-%S"`
weekly=$1

config_file="./config.properties"

log_dir=$(cat $config_file |grep log_dir | awk -F " " '{print $2}')
checkpoint_dir=$(cat $config_file | grep checkpoint_dir | awk -F " " '{print $2}')

gol_dir=$(cat $config_file |grep gol_dir | awk -F " " '{print $2}')
gol_dir=$(cd $gol_dir && pwd)
pointcheck_dir=$(cat $config_file | grep pointcheck_dir | awk -F " " '{print $2}')
pointcheck_dir=$(cd $pointcheck_dir && pwd)

deeprec_fp32_script="./benchmark_result/record/script/$currentTime/deeprec_fp32.sh"
deeprec_bf16_script="./benchmark_result/record/script/$currentTime/deeprec_bf16.sh"
tf_fp32_script="./benchmark_result/record/script/$currentTime/tf_fp32.sh"

deeprec_test_image=$(cat $config_file |grep deeprec_test_image | awk -F " " '{print$2}' )
tf_test_image=$(cat $config_file |grep tf_test_image | awk -F " " '{print$2}' )

sudo docker pull $deeprec_test_image
sudo docker pull $tf_test_image

deeprec_bf16_CMD=$(cat $config_file | grep CMD | grep deeprec_bf16 | awk -F ":" '{print$2}')
deeprec_fp32_CMD=$(cat $config_file | grep CMD | grep deeprec_fp32 | awk -F ":" '{print$2}')
tf_fp32_CMD=$(cat $config_file | grep CMD | grep tf_fp32 | awk -F ":" '{print$2}')

cpus=$(cat $config_file | grep cpus | awk -F " " '{print $2}')
env_var=$(cat $config_file |grep export)

[[ ! -d "./benchmark_result/record/script/$currentTime/" ]] && mkdir -p ./benchmark_result/record/script/$currentTime/
[[ ! -d $gol_dir/$currentTime ]] && mkdir -p "$gol_dir/$currentTime" 
[[ ! -d $pointcheck_dir/$currentTime ]] && mkdir -p "$pointcheck_dir/$currentTime"

make_script\
&& checkEnv\
&& runContainers\
&& python3 ./gstep_count.py --log_dir=$gol_dir/$currentTime \
&& upOss \
