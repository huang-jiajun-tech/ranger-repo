#!/bin/bash

##针对HDFS跟Hive的repository的创建
export CLUSTER_ID="br-ghy-bigdata-hive-prod-1"
export HDFS_URL="br-ghy-bigdata-hive-prod-1"
export RANGER_HOST="10.158.0.37"
export FIRST_MASTER_NODE="10.158.0.44"

function repo_create(){
	sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" ./open-source-hdfs-repo.json
	sed -i "s/@HDFS_URL@/${HDFS_URL}/g" ./open-source-hdfs-repo.json
	sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" ./open-source-hdfs-policy.json
	sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" ./open-source-hive-repo.json
	sed -i "s/@FIRST_MASTER_NODE@/${FIRST_MASTER_NODE}/g" ./open-source-hive-repo.json

	curl -iv -u admin:admin -d @open-source-hdfs-repo.json -H "Content-Type: application/json" \
	        -X POST http://${RANGER_HOST}:6080/service/public/api/repository/
	curl -iv -u admin:admin -d @open-source-hdfs-policy.json -H "Content-Type: application/json" \
	        -X POST http://${RANGER_HOST}:6080/service/public/api/policy/
	curl -iv -u admin:admin -d @open-source-hive-repo.json -H "Content-Type: application/json" \
	        -X POST http://${RANGER_HOST}:6080/service/public/api/repository/
}

repo_create
