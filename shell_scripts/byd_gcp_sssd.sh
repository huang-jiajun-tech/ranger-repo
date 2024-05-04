#!/bin/bash

# 设置环境变量
export OPENLDAP_HOST=$(/usr/share/google/get_metadata_value attributes/openldap-host)
export OPENLDAP_BASE_DN=$(/usr/share/google/get_metadata_value attributes/openldap-base-dn)
export SSSD_BIND_DN=$(/usr/share/google/get_metadata_value attributes/sssd-bind-dn)
export SSSD_BIND_PASSWORD=$(/usr/share/google/get_metadata_value attributes/sssd-bind-password)

function installSssdPackagesForOpenldap() {
	retry_command "apt-get update"
    retry_command "apt-get install sssd-tools sssd libnss-sss libpam-sss adcli samba-common-bin oddjob-mkhomedir ldap-utils -y"
}

function configSssdForOpenldap() {
    pam-auth-update --enable sssd --enable sssdauth --enable mkhomedir --enable rfc2307bis \
    --enable ldap --enable ldapauth --disable ldaptls  --disable forcelegacy --disable krb5 --update all
    # open mmkhomedir
    sed -i 's/Default: no/Default: yes/g' /usr/share/pam-configs/mkhomedir
    # second, append more config items in sssd.conf
    tee /etc/sssd/sssd.conf<<EOF
[sssd]
config_file_version = 2
domains = default
services = nss, pam, autofs

[domain/default]
ldap_schema = rfc2307bis
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${OPENLDAP_HOST}
cache_credentials = True
ldap_tls_reqcert = never
ldap_search_base = ${OPENLDAP_BASE_DN}
ldap_default_bind_dn = ${SSSD_BIND_DN}
ldap_default_authtok_type = password
ldap_default_authtok = ${SSSD_BIND_PASSWORD}
override_home=/home/%u
default_shell=/bin/bash
[nss]
homedir_substring = /home

EOF
    chmod 600 /etc/sssd/sssd.conf
}

function configSshdForSssd() {
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
}

function restartSssdRelatedServices() {
    systemctl enable sssd oddjobd
    systemctl restart sssd oddjobd sshd
    #systemctl status sssd oddjobd sshd
}

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
	# local role
	# role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
	
	# # 只在Master节点上安装
	# if [[ "${role}" == 'Master' ]]; then
	# 	installSssdPackagesForOpenldap
	# 	configSssdForOpenldap
	# 	configSshdForSssd
	# 	restartSssdRelatedServices
	# fi
    installSssdPackagesForOpenldap
    configSssdForOpenldap
    configSshdForSssd
    restartSssdRelatedServices
}

main