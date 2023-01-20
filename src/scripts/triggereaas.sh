#!/bin/bash
ROOST_AUTH_TOKEN=$(eval "echo \"\$$ORB_ENV_AUTH_TOKEN\"")
ENT_SERVER=$(eval "echo \"\$$ORB_ENV_ENT_SERVER\"")

pre_checks() {
  if [ -z "$ROOST_AUTH_TOKEN" ]; then
    echo "ROOST_AUTH_TOKEN not found. Please add ROOST_AUTH_TOKEN as an environment variable in CicleCI before continuing."
    exit 1
  fi
}

trigger_eaas() {
  EAAS_RESPONSE=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/triggerEaasFromCircleCI" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\": \"$ROOST_AUTH_TOKEN\",
    \"application_name\": \"$APPLICATION_NAME\",
    \"git_type\": \"$PIPELINE_PROJECT_TYPE\",
    \"repo_id\": \"\",
    \"full_repo_name\": \"$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME\",
    \"branch\": \"$CIRCLE_BRANCH\",
    \"circle_workflow_id\": \"$CIRCLE_WORKFLOW_ID\",
    \"user_name\": \"$CIRCLE_PROJECT_USERNAME\"
  }")

  TRIGGER_IDS=$(echo $EAAS_RESPONSE | jq -r '.trigger_ids[0]')
  if [ "$TRIGGER_IDS" == "null" ]; then
    ERROR_MSG=$(echo $EAAS_RESPONSE | jq -r '.message')
    echo "Failed to trigger Eaas. Reason: ${ERROR_MSG}. Please try again."
    exit 1
  else
    echo "Triggered Eaas Successfully."
    sleep 30
    get_eaas_status "$TRIGGER_IDS"
  fi
}

send_endpoint_to_roost() {
  TRIGGER_ID=$1
  URL_RESPONSE=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/client/git/addCircleCIUrl" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"circleci_build_url\": \"$CIRCLE_BUILD_URL\",
    \"circleci_loadbalancer_url\": \"$TF_OUTPUT_alb_loadbalancer\",
    \"trigger_id\": \"$TRIGGER_ID\",
    \"app_user_id\": \"$ROOST_AUTH_TOKEN\"
  }")
  echo $URL_RESPONSE
}

get_eaas_status() {
  TRIGGER_ID=$1
  RESPONSE=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/client/git/eaas/getStatus" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\" : \"${ROOST_AUTH_TOKEN}\",
    \"trigger_id\" : \"$TRIGGER_ID\"
  }")

  STATUS=$(echo -E "$RESPONSE" | jq -r '.infra_output.INFRA_STATUS')
  if [ -z "$STATUS" -o "$STATUS" == "null" ]; then
    STATUS=$(echo -E "$RESPONSE" | jq -r '.current_status')
  fi

  case "$STATUS" in
    infra_ops_in_progress)
      echo "Infra setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    infra_ops_completed)
      for key in $(echo -E "$RESPONSE" | jq -r '.infra_output | keys[]'); do
        if [ "$key" != "INFRA_STATUS" ]; then
          val=$(echo -E "$RESPONSE" | jq -r .infra_output.$key)
          echo "export '$key'='$val'" >> $BASH_ENV
        fi
      done
      echo "export status='$STATUS'" >> $BASH_ENV
      cp $BASH_ENV bash.env
      send_endpoint_to_roost $TRIGGER_ID
      echo "Infra setup is completed."
      ;;
    infra_ops_failed)
      echo "Infra setup failed. Please try again."
      exit 1
      ;;
    setup_in_progress)
      echo "Application setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    cluster_creation_in_progress)
      echo "Cluster creation in proggress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    build_in_progress)
      echo "Application build is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
    deploy_completed)
      echo "export status='$STATUS'" >> $BASH_ENV
      cp $BASH_ENV bash.env
      send_endpoint_to_roost $TRIGGER_ID
      echo "Application deployed successfully."
      ;;
    deploy_failed)
      echo "Failed to deploy application. Please try again."
      exit 1
      ;;
    *)
      echo "Application setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
  esac

}


main() {
  pre_checks
  trigger_eaas
}

main $*