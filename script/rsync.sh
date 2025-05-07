rsync -av --exclude=build/ ~/louzy/LaCoLSM/ skv-node1:~/louzy/LaCoLSM
rsync -av --exclude=build/ ~/louzy/LaCoLSM/ skv-node3:~/louzy/LaCoLSM
rsync -av --exclude=build/ ~/louzy/LaCoLSM/ skv-node4:~/louzy/LaCoLSM
cd ../build
make Server db_bench TimberSaw