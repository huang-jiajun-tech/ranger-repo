#!/bin/bash

#!/usr/bin/env bash


# -------------------------------------------------   TEST OpenLDAP CONNECTIVITY   ------------------------------------------------ #

# function testLdapConnectivity() {
#     printHeading "TEST OpenLDAP CONNECTIVITY"
#     ldapsearch -VV &>/dev/null
#     if [ ! "$?" = "0" ]; then
#         echo "Install ldapsearch for OpenLDAP connectivity test"
# 		apt-get update
#         apt-get -y install openldap-clients &>/dev/null
#     fi
#     echo "Searched following dn from OpenLDAP server with given configs:"
#     ldapsearch -x -LLL -D "$RANGER_BIND_DN" -w "$RANGER_BIND_PASSWORD" -H "$OPENLDAP_URL" -b "$OPENLDAP_BASE_DN" dn

#     if [ "$?" = "0" ]; then
#         echo "Connecting to OpenLDAP server is SUCCESSFUL!!"
#     else
#         echo "Connecting to OpenLDAP server is FAILED!!"
#         exit 1
#     fi
# }

# -------------------------------------------   Ranger Plugin Operations   ------------------------------------------- #


# function testRangerAdminConnectivityFromNodes() {
#     printHeading "TEST CONNECTIVITY FROM NODES TO RANGER"
#     if ! nc --version &>/dev/null; then
#         sudo apt-get -y install nc
#     fi
#     nc -vz $RANGER_HOST $RANGER_PORT
#     if [ "$?" = "0" ]; then
#         echo "Connecting to ranger server is SUCCESSFUL!!"
#     else
#         echo "Connecting to ranger server is FAILED!!"
#         exit 1
#     fi
# }
export CLUSTER_ID=$(/usr/share/google/get_metadata_value attributes/cluster-id)
export SOLR_HOST=$(/usr/share/google/get_metadata_value attributes/solr-host)
export RANGER_HOST=$(/usr/share/google/get_metadata_value attributes/ranger-host)
export DATA_BUCKET=$(/usr/share/google/get_metadata_value attributes/data-bucket)


# -------------------------------------   Open Source HDFS PlugIn Operations   --------------------------------------- #

function installRangerOpenSourceHdfsPlugin() {
    #printHeading "INSTALL RANGER HDFS PLUGIN"
    wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/plugin/ranger-2.2.0-hdfs-plugin.tar.gz
    tar -zxvf /opt/ranger-2.2.0-hdfs-plugin.tar.gz -C /opt &>/dev/null
    installFilesDir=/opt/ranger-2.2.0-hdfs-plugin
    confFile=$installFilesDir/install.properties
    # backup install.properties
    cp $confFile $confFile.$(date +%s)
    sed -i "s|@CLUSTER_ID@|${CLUSTER_ID}|g" $confFile
    sed -i "s|@SOLR_HOST@|${SOLR_HOST}|g" $confFile
    sed -i "s|@RANGER_HOST@|${RANGER_HOST}|g" $confFile

    installHome=/opt/ranger-2.2.0-hdfs-plugin

    #printHeading "INSTALL RANGER HDFS PLUGIN ON MASTER NODE"
    cp $installHome/lib/* /usr/lib/hadoop/lib
    cp $installHome/lib/* /usr/lib/hadoop-hdfs/lib
    cp -r $installHome/lib/ranger-hdfs-plugin-impl /usr/lib/hadoop/lib
    cp -r $installHome/lib/ranger-hdfs-plugin-impl /usr/lib/hadoop-hdfs/lib
    cp /usr/lib/hadoop/lib/ranger-hdfs-plugin-impl/commons-lang-2.6.jar /usr/lib/hadoop/lib/


    bash $installHome/enable-hdfs-plugin.sh
    restartNamenode
}

function restartNamenode() {
    #printHeading "RESTART NAMENODE"
    systemctl stop hadoop-hdfs-namenode
    systemctl start hadoop-hdfs-namenode
}

# -------------------------------------   Open Source Hive PlugIn Operations   --------------------------------------- #

function installRangerOpenSourceHivePlugin() {
    #printHeading "INSTALL RANGER HIVE PLUGIN"
    wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/plugin/ranger-2.2.0-hive-plugin.tar.gz    
    tar -zxvf /opt/ranger-2.2.0-hive-plugin.tar.gz -C /opt/ &>/dev/null
    installFilesDir=/opt/ranger-2.2.0-hive-plugin
    confFile=$installFilesDir/install.properties
    # backup install.properties
    cp $confFile $confFile.$(date +%s)
    sed -i "s|@CLUSTER_ID@|${CLUSTER_ID}|g" $confFile
    sed -i "s|@SOLR_HOST@|${SOLR_HOST}|g" $confFile
    sed -i "s|@RANGER_HOST@|${RANGER_HOST}|g" $confFile
    installHome=/opt/ranger-2.2.0-hive-plugin

    #printHeading "INSTALL RANGER HIVE PLUGIN ON MASTER NODE"
    cp $installHome/lib/* /usr/lib/hive/lib
    cp -r $installHome/lib/ranger-hive-plugin-impl /usr/lib/hive/lib

    bash $installHome/enable-hive-plugin.sh
    restartHiveServer2
}

function restartHiveServer2() {
    #printHeading "RESTART HIVESERVER2"
    systemctl daemon-reload
    systemctl stop hive-server2
    systemctl start hive-server2
}


# -------------------------------------   Open Source Hive PlugIn Operations   --------------------------------------- #
function installRangerOpenSourceYARNPlugin() {
    printHeading "INSTALL RANGER YARN PLUGIN"
    wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/plugin/ranger-2.2.0-yarn-plugin.tar.gz    
    tar -zxvf /opt/ranger-2.2.0-yarn-plugin.tar.gz -C /opt/ &>/dev/null
    installFilesDir=/opt/ranger-2.2.0-yarn-plugin
    confFile=$installFilesDir/install.properties
    # backup install.properties
    cp $confFile $confFile.$(date +%s)
    sed -i "s|@CLUSTER_ID@|${CLUSTER_ID}|g" $confFile
    sed -i "s|@SOLR_HOST@|${SOLR_HOST}|g" $confFile
    sed -i "s|@RANGER_HOST@|${RANGER_HOST}|g" $confFile
        
    printHeading "INSTALL RANGER HBASE PLUGIN ON MASTER: [ $(hostname) ]: "
    installHome=/opt/ranger-2.2.0-yarn-plugin
    
    # the enable-hbase-plugin.sh just work with open source version of hadoop,
    # for emr, we have to copy ranger jars to /usr/lib/hbase/lib/
    cp -r $installHome/lib/* /usr/lib/hadoop/lib
    cp -r $installHome/lib/ranger-yarn-plugin-impl /usr/lib/hadoop/lib

    bash $installHome/enable-yarn-plugin.sh
    chown yarn:hadoop /etc/ranger/YARN_${CLUSTER_ID}/.cred.jceks.crc

    systemctl restart hadoop-yarn-resourcemanager
}



function printHeading(){
    title="$1"
    if [ "$TERM" = "dumb" -o "$TERM" = "unknown" ]; then
        paddingWidth=60
    else
        paddingWidth=$((($(tput cols)-${#title})/2-5))
    fi
    printf "\n%${paddingWidth}s"|tr ' ' '='
    printf "    $title    "
    printf "%${paddingWidth}s\n\n"|tr ' ' '='
}

##retry command

function retry_command() {
  local cmd="$1"
  # First retry is immediate
  for ((i = 0; i < 10; i++)); do
    if eval "$cmd"; then
      return 0
    fi
    sleep $((i * 5))
  done
  return 1
}

function main(){
	local role
	role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
    # 只在第一台Master节点上安装
    d_hostname="$(hostname)"
    if [[ "${d_hostname}" == "${CLUSTER_ID}-m-0" ]]; then
        wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/cfg/open-source-hdfs-repo.json
        wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/cfg/open-source-hdfs-policy.json
        wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/cfg/open-source-hive-repo.json

        #新增yarn
        wget -P /opt https://storage.googleapis.com/${DATA_BUCKET}/cfg/open-source-yarn-repo.json

        sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" /opt/open-source-hdfs-repo.json
        sed -i "s/@HDFS_URL@/${CLUSTER_ID}/g" /opt/open-source-hdfs-repo.json
        sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" /opt/open-source-hdfs-policy.json
        sed -i "s/@CLUSTER_ID@/${CLUSTER_ID}/g" /opt/open-source-hive-repo.json
        sed -i "s/@FIRST_MASTER_NODE@/${d_hostname}/g" /opt/open-source-hive-repo.json

        #新增yarn
        sed -i "s|@CLUSTER_ID@|${CLUSTER_ID}|g" /opt/open-source-yarn-repo.json

        curl -iv -u admin:admin -d @/opt/open-source-hdfs-repo.json -H "Content-Type: application/json" \
                -X POST http://${RANGER_HOST}:6080/service/public/api/repository/
        curl -iv -u admin:admin -d @/opt/open-source-hdfs-policy.json -H "Content-Type: application/json" \
                -X POST http://${RANGER_HOST}:6080/service/public/api/policy/
        curl -iv -u admin:admin -d @/opt/open-source-hive-repo.json -H "Content-Type: application/json" \
                -X POST http://${RANGER_HOST}:6080/service/public/api/repository/
        curl -iv -u admin:admin -d @/opt/open-source-yarn-repo.json -H "Content-Type: application/json" \
                -X POST http://${RANGER_HOST}:6080/service/public/v2/api/service
    fi
	
	# 只在Master节点上安装
	if [[ "${role}" == 'Master' ]]; then
		installRangerOpenSourceHdfsPlugin
		installRangerOpenSourceHivePlugin
        installRangerOpenSourceYARNPlugin
	fi
}

main