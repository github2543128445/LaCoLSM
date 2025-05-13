rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node1:~/louzy/LaCoLSM
rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node3:~/louzy/LaCoLSM
rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node4:~/louzy/LaCoLSM
rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node5:~/louzy/LaCoLSM
rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node6:~/louzy/LaCoLSM
rsync -av --exclude=build/ --exclude=data/ --exclude=script/run-MN.sh --exclude=*.csv ~/louzy/LaCoLSM/ skv-node7:~/louzy/LaCoLSM
cd ../build
make Server db_bench TimberSaw