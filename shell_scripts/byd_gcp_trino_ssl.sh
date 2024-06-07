#!/bin/bash

#!/usr/bin/env bash

export RANGER_HOST=$(/usr/share/google/get_metadata_value attributes/ranger-host)
export TRINO_SRCERT="xxufENF0K5e7SgHSC75YazGKmn7RznwLrIUDDRZ9fH78julokc3DcUvBqzvFDb8j1miWnrrVxn3bEev493y2YpwjYtm0wpo9/tpU7UGCND3DClxNJOvb0SIf1F6aiVgvhHmg5NKilv+ygeek1R6xlPGPc2fAiIxVFVQx39KtKwdg0JD2WPC7LvU/A9u3+hTh2fg43P6AIWOXgvGJdybLDv1kyKdkm2PTy+UtAilqUjeCfwWRDJ1Nt484nP8p2bWDzJnnY8sB/NApx99NWsaZuP3dCkPjB4E69pxzLxzyHsBFuTrKKizw51BiX4EYDpCgNVVo9S9XLobsrzIW13hj9Z6LCKVmBfJPGSOr5zBYN6z2AzdACFooGUEuz+lEx9bcAkKl75Q0bR83dw0EWQxS6G9p7gLQVKIM+q3baXS20ksl97pcO5VbVVJyJJNTszTY2qBYWP0OVtU3MXxBQ7MEqm7Zv7W92warwLtB1VLwkVdn46ilQKIEsSOimgQRXZz5NkoQzSPxKdFAiJoEfXLaBufD7fgeYc4UNuruGOlKz0Bm/Rj9mYFQe7XRgaFnzYvvJgOHRdQoYIKsG0583/V5wOyBClbGXdgZq81HsXfVJ9R3ZurfZbIurVxy7dssc0NZaGIA5LWrx4N5zPDxU2BJbSFlDLUxXobW6yCXO0Np7so="


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
    openssl req -new -x509 -days 1825 -key /mnt/demoCA/private/cakey.pem -passin pass:"$PASSWORD" -out /mnt/demoCA/cacert.pem -extensions v3_req -config /mnt/demoCA/openssl.cnf -subj "$SUBJECT"
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
    cat << EOF >> /etc/trino/conf/config.properties
http-server.authentication.type = PASSWORD
http-server.https.enabled = true
http-server.https.keystore.path = /mnt/demoCA/certificate.p12
http-server.https.port = 8446
internal-communication.shared-secret = ${TRINO_SRCERT}
http-server.https.keystore.key = 1234
EOF
    cat << EOF > /etc/trino/conf/password-authenticator.properties
password-authenticator.name=ldap
ldap.url=ldap://${RANGER_HOST}:389
ldap.user-bind-pattern=uid=$\{USER\},ou=users,dc=test,dc=com
ldap.allow-insecure=true
EOF
    printHeading "Restart the Trino Service."
    systemctl restart trino
}

function trino_config_worker(){
    cat << EOF >> /etc/trino/conf/config.properties
internal-communication.shared-secret = ${TRINO_SRCERT}
EOF
    printHeading "Restart the Trino Service."
    systemctl restart trino
}


function main(){
	local role
	role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
    
    # 只在第一台Master节点上安装
    # d_hostname="$(hostname)"
    # if [[ "${d_hostname}" == "${CLUSTER_ID}-m-0" ]]; then
    #     repo_create
    # fi
	
	# 只在Master节点上安装
	if [[ "${role}" == 'Master' ]]; then
        trino_config_master
	fi
    if [[ "${role}" == 'Worker' ]]; then
        trino_config_worker
    fi
}

main