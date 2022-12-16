#!/bin/bash
ROOST_DIR="/var/tmp/Roost"
LOG_FILE="${ROOST_DIR}/cluster.log"

pre_checks() {
  ROOT_DISK_SIZE="${PARAM_DISK_SIZE}GB"
  KUBE_DIR="/home/vscode/.kube"
  if [ -z "${PARAM_ALIAS}" ]; then
    ALIAS=$(date +%s)
  fi
}

create_cluster() {
  RESPONSE_CODE=$(curl --location --request POST "https://${PARAM_ENT_SERVER}/api/application/client/launchCluster" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"roost_auth_token\": \"${PARAM_ROOST_AUTH_TOKEN}\",
    \"alias\": \"${ALIAS}\",
    \"namespace\": \"${PARAM_NAMESPACE}\",
    \"customer_email\": \"${PARAM_EMAIL}\",
    \"k8s_version\": \"${PARAM_K8S_VERSION}\",
    \"num_workers\": ${PARAM_NUM_WORKERS},
    \"preemptible\": ${PARAM_PREEMPTIBLE},
    \"cluster_expires_in_hours\": ${PARAM_CLUSTER_EXPIRY},
    \"region\": \"${PARAM_REGION}\",
    \"disk_size\": \"${ROOT_DISK_SIZE}\",
    \"instance_type\": \"$PARAM_INSTANCE_TYPE\",
    \"ami\": \"${PARAM_AMI}\"
  }" | jq -r '.ResponseCode')

  if [ "${RESPONSE_CODE}" -eq 0 ]; then
    sleep 5m
    for i in {1..10}
    do
      if [ ! -s ${KUBE_DIR}/config ]; then
        echo "$i sleeping now for 30s"
        sleep 30
        get_kubeconfig
      fi
    done
  else
    echo "Failed to launch cluster. please try again"
  fi
}

get_kubeconfig() {
  if [ ! -d "${KUBE_DIR}" ]; then
    mkdir -p ${KUBE_DIR}
  fi

  KUBECONFIG=$(curl --location --request POST "https://${PARAM_ENT_SERVER}/api/application/cluster/getKubeConfig" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\" : \"${PARAM_ROOST_AUTH_TOKEN}\",
    \"cluster_alias\" : \"${ALIAS}\"
  }" | jq -r '.kubeconfig')

  if [ "${KUBECONFIG}" != "null" ]; then
    echo "Kubconfig retrieved successfully"
    echo "${KUBECONFIG}" >> "${KUBE_DIR}/config"
  fi
}

write_stop_cmd() {

  cat > /usr/local/bin/roost \
<< EOF
ACTION=\$*
main() {
  case \$ACTION in
    stop)
      curl --location --request POST "https://${PARAM_ENT_SERVER}/api/application/client/stopLaunchedCluster" \
      --header "Content-Type: application/json" \
      --data-raw "{
        \"roost_auth_token\": \"${PARAM_ROOST_AUTH_TOKEN}\",
        \"alias\": \"${ALIAS}\"
      }"
      sudo rm -f "${KUBE_DIR}/config"
      ;;
    delete)
      curl --location --request POST "https://${PARAM_ENT_SERVER}/api/application/client/deleteLaunchedCluster" \
      --header "Content-Type: application/json" \
      --data-raw "{
        \"roost_auth_token\": \"${PARAM_ROOST_AUTH_TOKEN}\",
        \"alias\": \"${ALIAS}\"
      }"
      sudo rm -f "${KUBE_DIR}/config"
      ;;
    *)
      echo "Please try with valid parameter - stop or delete"
    ;;
  esac
}
main
EOF

chmod +x /usr/local/bin/roost
}

main() {
  pre_checks
  create_cluster
  write_stop_cmd
}

if [ ! -d "${ROOST_DIR}" ]; then
   mkdir -p ${ROOST_DIR}
fi

main "$*" > ${ROOST_DIR}/roost.log 2>&1
echo "Logs are at ${ROOST_DIR}/roost.log"