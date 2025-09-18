#!/bin/bash
cd ../build
make Server db_bench TimberSaw

taskset -c 40-43 ./Server 19843 80 0