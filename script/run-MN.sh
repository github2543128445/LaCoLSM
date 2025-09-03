#!/bin/bash
cd ../build
make Server db_bench TimberSaw

taskset -c 40-53 ./Server 19843 80 0