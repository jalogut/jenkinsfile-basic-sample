set +x
NODE_LIST=($(echo $NODES | sed "s/,/ /g"))
if [[ ${ACTIONS} = *"Test_performance"* ]]; then
  REPO_NAME="perf_test"
  git clone -b master --single-branch git@repos.igk.intel.com:intelcaffe ${REPO_NAME}
  cp ~/sources/models.tar ${REPO_NAME}/
  cp ~/sources/imagenet_mean.binaryproto ${REPO_NAME}/data/ilsvrc12/
  cd ${REPO_NAME}
  tar -xf models.tar
  rm -rf models.tar
  
  for NODE_IP in ${NODE_LIST[@]}
  do
    echo "192.168.1.${NODE_IP}" >> hostfile
  done
  DST_IP=$(head -n 1 hostfile)
  cd ..
  tar -cf ${REPO_NAME}.tar ${REPO_NAME}
  scp ${REPO_NAME}.tar ${DST_IP}:~/
  rm -rf ${REPO_NAME}.tar ${REPO_NAME}
fi

COMPILE=true
for NODE_IP in ${NODE_LIST[@]}
do
SERVER="192.168.1.${NODE_IP}"
ssh $SERVER bash <<EOF
  set +x
  echo "SERVER: ${SERVER}"
  SERVER=${SERVER}
  for TASK in $(echo $ACTIONS | sed "s/,/ /g")
  do
    case "\$TASK" in
        Kill_zombie_processes)
          for i in \$(ps -e | grep ep_server | sed "s/ ?.*//");do kill -9 \$i; echo "ep_server process \$i killed."; done
          for i in \$(ps -e | grep caffe | sed "s/ ?.*//");do kill -9 \$i; echo "Caffe process \$i killed."; done
          ;;
        Clear_cache)
          sudo sh -c 'sync; echo 1 > /proc/sys/vm/drop_caches'
          echo "Page cache droped"
          ;;
        Clear_shm_memory)
          rm -rf /dev/shm/*
          echo "Shm memory cleared"
          ;;
        Test_performance)
          MODEL=models/nodata/bvlc_alexnet/train_val.prototxt
          if [ \$SERVER == "192.168.1.${NODE_LIST[0]}" ]; then
            export MKLROOT="/opt/mklml_lnx_2017.0.2.20170110"
            export MKLDNNROOT=""
            rm -rf ${REPO_NAME}
            
            cd ~/
            tar -xf ${REPO_NAME}.tar
            cd ${REPO_NAME}
            mkdir build
            cd build
  
            cmake .. -DCMAKE_BUILD_TYPE=Release -DBLAS=mkl &> output.log
            make all -j &>> output.log
            cd ..
            sed -i '/solver_mode: / s/.PU/CPU/' \$MODEL
            ansible all -i "hostfile" -m synchronize -a "src=~/${REPO_NAME}/ dest=~/${REPO_NAME}" &>> output.log
          fi
          cd ~/${REPO_NAME}
          OMP_NUM_THREADS=66 ./build/tools/caffe time --model=\$MODEL -iterations 100 -engine=MKL2017 &>> output.log
          grep "Average Forward-Backward" output.log | sed "s/.*\] //"
          ;;
    esac
  done
EOF
done