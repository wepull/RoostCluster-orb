#!/bin/bash

#echo $ROOST_AUTH_TOKEN
#echo $PIPELINE_PROJECT_TYPE
#echo $CIRCLE_PR_REPONAME
#echo $CIRCLE_BRANCH
#echo $CIRCLE_WORKFLOW_ID
#echo $CIRCLE_PR_USERNAME

#ROOST_DIR="/var/tmp/Roost"
#LOG_FILE="$ROOST_DIR/cluster.log"



trigger_eaas() {
  TRIGGER_IDS=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/triggerEaasFromCircleCI" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\": \"$ROOST_AUTH_TOKEN\",
    \"application_name\": \"eaastest\",
    \"git_type\": \"github\",
    \"repo_id\": \"\",
    \"full_repo_name\": \"$CIRCLE_PROJECT_REPONAME\",
    \"branch\": \"$CIRCLE_BRANCH\",
    \"circle_workflow_id\": \"$CIRCLE_WORKFLOW_ID\",
    \"user_name\": \"$CIRCLE_PROJECT_USERNAME\"
  }" | jq -r '.trigger_ids[0]')

  if [ "$TRIGGER_IDS" != "null" ]; then
    echo "Triggered Eaas Successfully."
    get_eaas_status "$TRIGGER_IDS"
  else
    echo "Failed to trigger Eaas. Please try again."
  fi
}

get_eaas_status() {

  TRIGGER_ID=$1
  STATUS=$(curl --location --silent --request POST "https://$ENT_SERVER/api/application/client/git/eaas/getStatus" \
  --header "Content-Type: application/json" \
  --data-raw "{
    \"app_user_id\" : \"$ROOST_AUTH_TOKEN\",
    \"trigger_id\" : \"$TRIGGER_ID\"
  }" | jq -r '.current_status')

  case "$STATUS" in
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
      echo "Application deployed successfully."
      ;;
    deploy_failed)
      echo "Failed to deploy application. Please try again."
      ;;
    *)
      echo "Application setup is in progress."
      sleep 30
      get_eaas_status $TRIGGER_ID
      ;;
  esac

}


main() {
  trigger_eaas
}

if [ ! -d "$ROOST_DIR" ]; then
   mkdir -p ${ROOST_DIR}
fi

main $* > $ROOST_DIR/roost.log 2>&1
echo "Logs are at $ROOST_DIR/roost.log"
