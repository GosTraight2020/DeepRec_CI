echo 'testing WDL of tf_fp32.......'
cd ~/modelzoo/WDL/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/wdl_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/wdl_tf_fp32.log 2>&1
echo 'testing DSSM of tf_fp32.......'
cd ~/modelzoo/DSSM/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/dssm_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/dssm_tf_fp32.log 2>&1
echo 'testing DLRM of tf_fp32.......'
cd ~/modelzoo/DLRM/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/dlrm_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/dlrm_tf_fp32.log 2>&1
echo 'testing DeepFM of tf_fp32.......'
cd ~/modelzoo/DeepFM/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/deepfm_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/deepfm_tf_fp32.log 2>&1
echo 'testing DIEN of tf_fp32.......'
cd ~/modelzoo/DIEN/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/dien_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/dien_tf_fp32.log 2>&1
echo 'testing DIN of tf_fp32.......'
cd ~/modelzoo/DIN/
LD_PRELOAD=~/modelzoo/libjemalloc.so.2.5.1 numactl -C 52-55,164-167 -l  python train.py  --steps 3000 --no_eval --timeline 1000 --checkpoint /2022-03-10-10-51-36/din_tf_fp32 >/home/shanlin/DeepRec_CI/SPR_gstep_benchmark/benchmark_result/log/2022-03-10-10-51-36/din_tf_fp32.log 2>&1
