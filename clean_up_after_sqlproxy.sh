#!/usr/bin/env bash
# Get list of helm P4 deployments on version 0.8.5
# run with site env = develop, release or master.
# Do I have to check kubectx exists?
# Delete 4 orphaned pods resulting from the change to the cloud sql proxy
# Remove OpenIAM Cloud SQL client role from service user

set -o pipefail

# Set Variables
#This is the chart version of all NRO envs migrated to the new CloudSQL proxy
CHART_VERSION=0.8.9
SITE_ENV=$1

if [ -z "$1" ]
 then echo "Please enter environment ie. develop, release or master"
 exit 0
fi


if SITE_ENV="develop"
  then
    GOOGLE_PROJECT_ID="planet-4-151612"
    RELEASE=""
    kubectx gke_"$GOOGLE_PROJECT_ID"_us-central1-a_p4-development
  elif SITE_ENV="release"
  then
    GOOGLE_PROJECT_ID="planet4-production"
    RELEASE="-release"
    kubectx gke_"$GOOGLE_PROJECT_ID"_us-central1-a_planet4-production
  else
    GOOGLE_PROJECT_ID="planet4-production"
    RELEASE="-master"
    kubectx gke_"$GOOGLE_PROJECT_ID"_us-central1-a_planet4-production
  mkdir -p /tmp/$SITE_ENV
  cd /tmp/$SITE_ENV  || exit
fi

# Find out if anything needs to be cleaned up

DEPLOYMENT_COUNT=$(helm ls | grep planet4 | grep -c wordpress-$CHART_VERSION)
echo "$DEPLOYMENT_COUNT"

if (( DEPLOYMENT_COUNT > 0 ))
then
  echo "There are $DEPLOYMENT_COUNT deployments with orphaned proxy objects in ${SITE_ENV}, prepare to delete"
  read -rsp $'Press enter to continue...\n'

# This should only happen once as its the same user for all projects
  if SITE_ENV="develop"
    then
#      IAM_NAME=$(helm ls | grep planet4 | grep wordpress-$CHART_VERSION | sed -n 1p | cut -d' ' -f1 | cut -d "-" -f2 )
      helm ls | grep planet4 | grep wordpress-$CHART_VERSION | cut -d' ' -f1 | cut -d "-" -f2 >> iam_name_list

      while read -r IAM_NAME
       do
         echo "Removing the following $DEPLOYMENT_NAME CloudSQL Client OpenIAM Role"
         echo "gcloud projects remove-iam-policy-binding my-project /
           --member user:$IAM_NAME@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com /
           --role roles/cloudsql.client"

#commenting this out for testing... probs some way to run this without doing it ...
       # gcloud projects remove-iam-policy-binding my-project \
       #  --member user:$IAM_NAME@planet-4-151612.iam.gserviceaccount.com \
       #  --role roles/cloudsql.client
       # >> /tmp/$SITE_ENV/iam_name_roles_removed

     done < iam_name_list
      rm iam_name_list

    fi


# Get details of what to clean up

helm ls | grep planet4 | grep wordpress-$CHART_VERSION | cut -d' ' -f1 >> nro_env_name

    while read -r DEPLOYMENT_NAME
     do

      echo "Deleting the following $DEPLOYMENT_NAME$RELEASE orphaned proxy objects"
      echo "kubectl delete networkpolicy $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy"
      echo "kubectl delete secret $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy"
      echo "kubectl delete service $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy"
      echo "kubectl delete PodDisruptionBudget $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy"

#commenting this out for testing... probs some way to run this without doing it ...

      # kubectl delete networkpolicy $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy
      # kubectl delete secret $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy
      # kubectl delete service $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy
      # kubectl delete PodDisruptionBudget $DEPLOYMENT_NAME$RELEASE-gcloud-sqlproxy

    done < nro_env_name
     rm nro_env_name

else
  echo "No deployments with orphaned proxy objects exist in ${SITE_ENV}, finishing now."
  exit 0
fi
