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
    gcloud storage cp gs://${DATA_BUCKET}/plugin/ranger-2.2.0-hdfs-plugin.tar.gz /opt/
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
    cp $installHome/lib/*.jar /usr/lib/hadoop/lib
    cp $installHome/lib/*.jar /usr/lib/hadoop-hdfs/lib
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
    gcloud storage cp gs://${DATA_BUCKET}/plugin/ranger-2.2.0-hive-metastore-plugin.tar.gz /opt/
    tar -zxvf /opt/ranger-2.2.0-hive-metastore-plugin.tar.gz -C /opt/ &>/dev/null
    installFilesDir=/opt/ranger-2.2.0-hive-plugin
    confFile=$installFilesDir/install.properties
    # backup install.properties
    cp $confFile $confFile.$(date +%s)
    sed -i "s|@CLUSTER_ID@|${CLUSTER_ID}|g" $confFile
    sed -i "s|@SOLR_HOST@|${SOLR_HOST}|g" $confFile
    sed -i "s|@RANGER_HOST@|${RANGER_HOST}|g" $confFile
    installHome=/opt/ranger-2.2.0-hive-plugin

    #printHeading "INSTALL RANGER HIVE PLUGIN ON MASTER NODE"
    cp $installHome/lib/*.jar /usr/lib/hive/lib
    cp -r $installHome/lib/ranger-hive-plugin-impl /usr/lib/hive/lib

    bash $installHome/enable-hive-plugin.sh

    unlink /usr/lib/hive/lib/ranger-hive-plugin-impl
    cp $installHome/lib/ranger-hive-plugin-impl/*.jar /usr/lib/hive/lib

    sed -i "$i\
  <property>\
    <name>hive.metastore.pre.event.listeners</name>\
    <value>org.apache.ranger.authorization.hive.authorizer.RangerHiveMetastoreAuthorizer</value>\
  </property>\
  <property>\
    <name>hive.metastore.event.listeners</name>\
    <value>org.apache.ranger.authorization.hive.authorizer.RangerHiveMetastorePrivilegeHandler</value>\
  </property>\
  <property>\
    <name>hive.conf.restricted.list</name>\
    <value>hive.security.authorization.enabled,hive.security.authorization.manager,hive.security.authenticator.manager</value>" /etc/hive/conf/hive-site.xml
    
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
    gcloud storage cp gs://${DATA_BUCKET}/plugin/ranger-2.2.0-yarn-plugin.tar.gz /opt/
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
    cp -r $installHome/lib/*.jar /usr/lib/hadoop/lib
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

function repo_create(){
    gcloud storage cp gs://${DATA_BUCKET}/cfg/open-source-hdfs-repo.json /opt/
    gcloud storage cp gs://${DATA_BUCKET}/cfg/open-source-hdfs-policy.json /opt/
    gcloud storage cp gs://${DATA_BUCKET}/cfg/open-source-hive-repo.json /opt/

    #新增yarn
    gcloud storage cp gs://${DATA_BUCKET}/cfg/open-source-yarn-repo.json

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

    printHeading "The ranger repository is created."
}


function cacreate(){
    mkdir -p /mnt/demoCA && cd /mnt/demoCA

    #获取ip地址
    #commonName和IP必须和主机的hostname与IP相同。
    #local_ipv4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    local_ipv4=$(hostname -I | awk '{print $1}')
    local_hostname=$(hostname)
    local_hostname_long=$(hostname -f)

    cat << EOF > openssl.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req


[req_distinguished_name]
countryName                     = Country Name (2 letter code)
countryName_default             = US
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = California
localityName                    = Locality Name (eg, city)
localityName_default            = San Francisco
organizationName                = Organization Name (eg, company)
organizationName_default        = My Company
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = IT Department
commonName                      = ${local_hostname}
commonName_max                  = 64


[v3_req]
basicConstraints = CA:TRUE
subjectAltName = @alt_names

[alt_names]
IP.1 = ${local_ipv4}
DNS.1 = ${local_hostname}
DNS.2 = ${local_hostname_long}
EOF

    #创建 CA 目录结构
    mkdir -p /mnt/demoCA/private
    mkdir -p /mnt/demoCA/newcerts
    touch /mnt/demoCA/index.txt
    echo 01 > /mnt/demoCA/serial
    # 生成 CA 的 RSA 密钥对
    PASSWORD="1234"
    openssl genrsa -des3 -out /mnt/demoCA/private/cakey.pem -passout pass:"$PASSWORD" 2048

    # 自签发 CA 证书
    PASSWORD="1234"
    local_hostname=$(hostname)
    SUBJECT="/C=US/ST=California/L=San Francisco/O=My Company/OU=IT Department/CN=${local_hostname}"
    openssl req -new -x509 -days 365 -key /mnt/demoCA/private/cakey.pem -passin pass:"$PASSWORD" -out /mnt/demoCA/cacert.pem -extensions v3_req -config /mnt/demoCA/openssl.cnf -subj "$SUBJECT"
    # 查看证书内容
    openssl x509 -in /mnt/demoCA/cacert.pem -noout -text
    # 设置输入密码（cakey.pem的密码）
    IN_PASSWORD="1234"
    # 设置输出密码（生成的P12文件的密码）
    OUT_PASSWORD="1234"
    # 生成PKCS12文件
    openssl pkcs12 -inkey /mnt/demoCA/private/cakey.pem -in /mnt/demoCA/cacert.pem -export -out /mnt/demoCA/certificate.p12 -passin pass:"$IN_PASSWORD" -passout pass:"$OUT_PASSWORD"

    # 默认密码通常为"changeit"
    KEYSTORE_PASSWORD="changeit"
    ALIAS="mytrinoserver2"
    CERT_FILE="/mnt/demoCA/cacert.pem"
    #KEYSTORE_PATH="/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.372.b07-1.amzn2.0.1.x86_64/jre/lib/security/cacerts"
    KEYSTORE_PATH="/usr/lib/jvm/temurin-11-jdk-amd64/lib/security/cacerts"
    # 导入证书到密钥库
    sudo keytool -import -alias "$ALIAS" -file "$CERT_FILE" -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" -noprompt
}


function trino_config_master(){
    cacreate

}

function trino_config_worker(){
    
}


function main(){
	local role
	role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
    
    # 只在第一台Master节点上安装
    d_hostname="$(hostname)"
    if [[ "${d_hostname}" == "${CLUSTER_ID}-m-0" ]]; then
        repo_create
    fi
	
	# 只在Master节点上安装
	if [[ "${role}" == 'Master' ]]; then
		installRangerOpenSourceHdfsPlugin
		installRangerOpenSourceHivePlugin
        installRangerOpenSourceYARNPlugin
        trino_config
	fi
}

main