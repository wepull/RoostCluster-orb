#!/bin/bash
ORB_ROOST_AUTH_TOKEN=$(eval "echo \"\$$ROOST_AUTH_TOKEN\"")

pre_checks() {
  if [ -z "$ORB_ROOST_AUTH_TOKEN" ]; then
    echo "The ROOST_AUTH_TOKEN is not found. Please add the ROOST_AUTH_TOKEN as an environment variable in CicleCI before continuing."
    exit 1
  fi

  ROOT_DISK_SIZE="${DISK_SIZE}GB"
  if [ -z "${ALIAS}" ]; then
    ALIAS=$(date +%s)
  fi
}

create_cluster() {
  RESPONSE_CODE=$(curl --location --request POST "https://${ENT_SERVER}/api/application/client/launchCluster" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"roost_auth_token\": \"$ORB_ROOST_AUTH_TOKEN\",
    \"alias\": \"${ALIAS}\",
    \"namespace\": \"${NAMESPACE}\",
    \"customer_email\": \"${EMAIL}\",
    \"k8s_version\": \"${K8S_VERSION}\",
    \"num_workers\": ${NUM_WORKERS},
    \"preemptible\": ${PREEMPTIBLE},
    \"cluster_expires_in_hours\": ${CLUSTER_EXPIRY},
    \"region\": \"${REGION}\",
    \"disk_size\": \"${ROOT_DISK_SIZE}\",
    \"instance_type\": \"$INSTANCE_TYPE\",
    \"ami\": \"${AMI}\"
  }" | jq -r '.ResponseCode')

  if [ "${RESPONSE_CODE}" -eq 0 ]; then
    get_kubeconfig
  else
    echo "Failed to launch cluster. please try again"
  fi
}

get_kubeconfig() {
  sleep 5m
  for i in {1..10}
  do
    KUBECONFIG=$(curl --location --request POST "https://${ENT_SERVER}/api/application/cluster/getKubeConfig" \
    --header "Content-Type: application/json" \
    --data-raw "{
      \"app_user_id\" : \"${ORB_ROOST_AUTH_TOKEN}\",
      \"cluster_alias\" : \"${ALIAS}\"
    }" | jq -r '.kubeconfig')

    if [ "${KUBECONFIG}" == "null" ]; then
      echo "$i sleeping now for 30s"
      sleep 30
    else
      echo "Cluster created successfully."
      break
    fi
  done
}

main() {
  pre_checks
  create_cluster
}

main $*