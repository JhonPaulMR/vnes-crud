#!/usr/bin/env bash
# =====================================================================
# openrc do usuario vnes-devops (projeto vnes). Use com:  source vnes-devops-openrc.sh
# A senha NAO fica no arquivo: e pedida (read -s) ou lida de OS_PASSWORD.
# =====================================================================
export OS_AUTH_URL=http://192.168.50.20/identity
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_TYPE=password
export OS_PROJECT_NAME=vnes
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USERNAME=vnes-devops
export OS_USER_DOMAIN_NAME=Default
export OS_REGION_NAME=RegionOne
export OS_INTERFACE=public
if [[ -z "${OS_PASSWORD:-}" ]]; then
  read -r -s -p "Senha do usuario vnes-devops: " OS_PASSWORD
  echo
  export OS_PASSWORD
fi
