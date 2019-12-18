#!/bin/bash


cat source/common.sh source/worker.sh > generated/worker_report.sh
cat source/common.sh source/onprem.sh > generated/onprem_report.sh
