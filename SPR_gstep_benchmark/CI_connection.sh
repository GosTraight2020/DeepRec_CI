
function get_row()
{
        catg=$1
        tag=$2

        res=$(cat $config_file| grep -n ${catg}_${tag}_TAG | awk -F ":" '{print $1}')
	echo $res
}


function clear_command_history()
{

	DP32=$(cat $config_file| grep CMD |grep deeprec_fp32)
	DP16=$(cat $config_file| grep CMD |grep deeprec_bf16)
	TF32=$(cat $config_file| grep CMD |grep tf)


	if [[ -n $DP16  ]];then
		deeprec16_begin=$(get_row DEEPREC_BF16 BEGIN)
		deeprec16_end=$(get_row DEEPREC_BF16 END)
		declare -i deeprec16_begin=$deeprec16_begin+2
		declare -i deeprec16_end=$deeprec16_end-2
		sed -i "$deeprec16_begin,$deeprec16_end d" $config_file 
	fi

	if [[ -n $DP32 ]];then
		deeprec32_begin=$(get_row DEEPREC_FP32 BEGIN) 
		deeprec32_end=$(get_row DEEPREC_FP32 END ) 
		declare -i deeprec32_begin=$deeprec32_begin+2
		declare -i deeprec32_end=$deeprec32_end-2
		sed -i "$deeprec32_begin,$deeprec32_end d" $config_file
	fi

	if [[ -n $TF32 ]];then
		tf32_begin=$(get_row TF_FP32 BEGIN)
		tf32_end=$(get_row TF_FP32 END)
		declare -i tf32_begin=$tf32_begin+2
		declare -i tf32_end=$tf32_end-2
		sed -i "$tf32_begin,$tf32_end d" $config_file
	fi

}

function make_cmd()
{
	old_IFS=$IFS	

	for model in $model_list
	do
			[[ $deeprec_bf16_param1 != "/" ]]&&sed -i "/##########1/a\CMD ${model}_deeprec_bf16:python train.py | $deeprec_bf16_param1" $config_file
			[[ $deeprec_bf16_param2 != "/" ]]&&sed -i "/##########1/a\CMD ${model}_deeprec_bf16:python train.py | $deeprec_bf16_param2" $config_file	
	done
		
	for model in $model_list
	do
			[[ $deeprec_fp32_param1 != "/" ]]&&sed -i "/##########3/a\CMD ${model}_deeprec_fp32:python train.py | $deeprec_fp32_param1" $config_file
			[[ $deeprec_fp32_param2 != "/" ]]&&sed -i "/##########3/a\CMD ${model}_deeprec_fp32:python train.py | $deeprec_fp32_param2" $config_file
	done
	
	for model in $model_list
	do
			[[ $tf_param != '/' ]] && sed -i "/##########5/a\CMD ${model}_tf_fp32:python train.py | $tf_param" $config_file
	done
	echo "Finished making command"

}

model_list=$1
deeprec_bf16_param1=$2
deeprec_bf16_param2=$3
deeprec_fp32_param1=$4
deeprec_fp32_param2=$5
tf_param=$6
weekly_tag=$7

config_file="./config.properties"
clear_command_history
make_cmd
