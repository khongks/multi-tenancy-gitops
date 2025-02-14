#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

command -v gh >/dev/null 2>&1 || { echo >&2 "The Github CLI gh but it's not installed. Download https://github.com/cli/cli "; exit 1; }

set +e
oc version --client | grep '4.7\|4.8'
OC_VERSION_CHECK=$?
set -e
if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
  echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
fi


if [[ -z ${GIT_ORG} ]]; then
  echo "We recommend to create a new github organization for all your gitops repos"
  echo "Setup a new organization on github https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch"
  echo "Please set the environment variable GIT_ORG when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
fi

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
fi
mkdir -p "${OUTPUT_DIR}"


SEALED_SECRET_KEY_FILE=${SEALED_SECRET_KEY_FILE:-~/Downloads/sealed-secrets-ibm-demo-key.yaml}

if [[ ! -f ${SEALED_SECRET_KEY_FILE} ]]; then
  echo "File Not Found: ${SEALED_SECRET_KEY_FILE}"

  exit 1
fi

CP_EXAMPLES=${CP_EXAMPLES:-true}

GITOPS_PROFILE=${GITOPS_PROFILE:-0-bootstrap/argocd/single-cluster/bootstrap.yaml}

GIT_BASEURL=${GIT_BASEURL:-https://github.com}
GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}
GITOPS_BRANCH=${GITOPS_BRANCH:-master}

IBM_CP_IMAGE_REGISTRY=${IBM_CP_IMAGE_REGISTRY:-cp.icr.io}

fork_repos () {
    echo "Github user/org is ${GIT_ORG}"

    pushd ${OUTPUT_DIR}

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-ace -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-ace" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit-demos/multi-tenancy-gitops-ace --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops-ace gitops-0-bootstrap-ace
    elif [[ ! -d gitops-0-bootstrap-ace ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-ace gitops-0-bootstrap-ace
    fi
    cd gitops-0-bootstrap-ace
    git remote set-url --push upstream no_push
    git checkout ${GITOPS_BRANCH} || git checkout --track origin/${GITOPS_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-infra -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-infra" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit/multi-tenancy-gitops-infra --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops-infra gitops-1-infra
    elif [[ ! -d gitops-1-infra ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps gitops-1-infra
    fi
    cd gitops-1-infra
    git remote set-url --push upstream no_push
    git checkout ${GITOPS_BRANCH} || git checkout --track origin/${GITOPS_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-services -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-services" ]]; then
      echo "Fork not found, creating fork and cloning"
      gh repo fork cloud-native-toolkit/multi-tenancy-gitops-services --clone --org ${GIT_ORG} --remote
      mv multi-tenancy-gitops-services gitops-2-services
    elif [[ ! -d gitops-2-services ]]; then
      echo "Fork found, repo not cloned, cloning repo"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps gitops-2-services
    fi
    cd gitops-2-services
    git remote set-url --push upstream no_push
    git checkout ${GITOPS_BRANCH} || git checkout --track origin/${GITOPS_BRANCH}
    cd ..

    if [[ "${CP_EXAMPLES}" == "true" ]]; then
      echo "Creating repos for Cloud Pak examples"

      GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-apps -q .name || true)
      if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-apps" ]]; then
        echo "Fork not found, creating fork and cloning"
        gh repo fork cloud-native-toolkit-demos/multi-tenancy-gitops-apps --clone --org ${GIT_ORG} --remote
        mv multi-tenancy-gitops-apps gitops-3-apps
      elif [[ ! -d gitops-3-apps ]]; then
        echo "Fork found, repo not cloned, cloning repo"
        gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps gitops-3-apps
      fi
      cd gitops-3-apps
      git remote set-url --push upstream no_push
      git checkout ${GITOPS_BRANCH} || git checkout --track origin/${GITOPS_BRANCH}
      cd ..

      GHREPONAME=$(gh api /repos/${GIT_ORG}/ace-customer-details -q .name || true)
      if [[ ! ${GHREPONAME} = "ace-customer-details" ]]; then
        echo "Fork not found, creating fork and cloning"
        gh repo fork cloud-native-toolkit-demos/ace-customer-details --clone --org ${GIT_ORG} --remote
        mv ace-customer-details src-ace-app-customer-details
      elif [[ ! -d src-ace-app-customer-details ]]; then
        echo "Fork found, repo not cloned, cloning repo"
        gh repo clone ${GIT_ORG}/ace-customer-details src-ace-app-customer-details
      fi
      cd src-ace-app-customer-details
      git remote set-url --push upstream no_push
      git checkout master || git checkout --track origin/${GITOPS_BRANCH}
      cd ..

    fi

    popd

}



init_sealed_secrets () {
    echo "Intializing sealed secrets with file ${SEALED_SECRET_KEY_FILE}"
    oc new-project sealed-secrets || true

    oc apply -f ${SEALED_SECRET_KEY_FILE}
}

install_pipelines () {
  echo "Installing OpenShift Pipelines Operator"
  oc apply -n openshift-operators -f https://raw.githubusercontent.com/cloud-native-toolkit/multi-tenancy-gitops-services/master/operators/openshift-pipelines/operator.yaml
}

install_argocd () {
    echo "Installing OpenShift GitOps Operator for OpenShift v4.7"
    pushd ${OUTPUT_DIR}
    oc apply -f gitops-0-bootstrap-ace/setup/ocp47/
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done
    while ! oc wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n openshift-gitops > /dev/null; do sleep 30; done
    popd
}

delete_default_argocd_instance () {
    echo "Delete the default ArgoCD instance"
    pushd ${OUTPUT_DIR}
    oc delete gitopsservice cluster -n openshift-gitops || true
    oc delete argocd openshift-gitops -n openshift-gitops || true
    popd
}

create_custom_argocd_instance () {
    echo "Create a custom ArgoCD instance with custom checks"
    pushd ${OUTPUT_DIR}

    oc apply -f gitops-0-bootstrap-ace/setup/ocp47/argocd-instance/ -n openshift-gitops
    while ! oc wait pod --timeout=-1s --for=condition=ContainersReady -l app.kubernetes.io/name=openshift-gitops-cntk-server -n openshift-gitops > /dev/null; do sleep 30; done
    popd
}

gen_argocd_patch () {
echo "Generating argocd instance patch for resourceCustomizations"
pushd ${OUTPUT_DIR}
cat <<EOF >argocd-instance-patch.yaml
spec:
  resourceCustomizations: |
    argoproj.io/Application:
      ignoreDifferences: |
        jsonPointers:
        - /spec/source/targetRevision
        - /spec/source/repoURL
    argoproj.io/AppProject:
      ignoreDifferences: |
        jsonPointers:
        - /spec/sourceRepos
EOF
popd
}

patch_argocd () {
  echo "Applying argocd instance patch"
  pushd ${OUTPUT_DIR}
  oc patch -n openshift-gitops argocd openshift-gitops --type=merge --patch-file=argocd-instance-patch.yaml
  popd
}

create_argocd_git_override_configmap () {
echo "Creating argocd-git-override configmap file ${OUTPUT_DIR}/argocd-git-override-configmap.yaml"
pushd ${OUTPUT_DIR}

cat <<EOF >argocd-git-override-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-git-override
data:
  map.yaml: |-
    map:
    - upstreamRepoURL: ${GIT_BASEURL}/cloud-native-toolkit/${GIT_GITOPS}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS}
      originBranch: ${GITOPS_BRANCH}
    - upstreamRepoURL: ${GIT_BASEURL}/cloud-native-toolkit/${GIT_GITOPS_INFRA}
      originRepoUrL: https://github.com/${GIT_ORG}/${GIT_GITOPS_INFRA}
      originBranch: ${GITOPS_BRANCH}
    - upstreamRepoURL: ${GIT_BASEURL}/cloud-native-toolkit/${GIT_GITOPS_SERVICES}
      originRepoUrL: ${GIT_BASEURL}/${GIT_ORG}/${GIT_GITOPS_SERVICES}
      originBranch: ${GITOPS_BRANCH}
    - upstreamRepoURL: ${GIT_BASEURL}/cloud-native-toolkit/${GIT_GITOPS_APPLICATIONS}
      originRepoUrL: ${GIT_BASEURL}${GIT_ORG}/${GIT_GITOPS_APPLICATIONS}
      originBranch: ${GITOPS_BRANCH}
EOF

popd
}

apply_argocd_git_override_configmap () {
  echo "Applying ${OUTPUT_DIR}/argocd-git-override-configmap.yaml"
  pushd ${OUTPUT_DIR}

  oc apply -n openshift-gitops -f argocd-git-override-configmap.yaml

  popd
}
argocd_git_override () {
  echo "Deploying argocd-git-override webhook"
  oc apply -n openshift-gitops -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/deployment.yaml
  oc apply -f https://github.com/csantanapr/argocd-git-override/releases/download/v1.1.0/webhook.yaml
  oc label ns openshift-gitops cntk=experiment --overwrite=true
  sleep 5
  oc wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n openshift-gitops > /dev/null
}

deploy_bootstrap_argocd () {
  echo "Deploying top level bootstrap ArgoCD Application for cluster profile ${GITOPS_PROFILE}"
  pushd ${OUTPUT_DIR}
  oc apply -n openshift-gitops -f gitops-0-bootstrap-ace/${GITOPS_PROFILE}
  popd
}


update_pull_secret () {
  if [[ -z "${IBM_ENTITLEMENT_KEY}" ]]; then
    echo "Please pass the environment variable IBM_ENTITLEMENT_KEY"
    exit 1
  fi
  WORKDIR=$(mktemp -d)
  # extract using oc get secret
  oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' >${WORKDIR}/.dockerconfigjson
  ls -l ${WORKDIR}/.dockerconfigjson

  # or extract using oc extract
  #oc extract secret/pull-secret --keys .dockerconfigjson -n openshift-config --confirm --to=-
  #oc extract secret/pull-secret --keys .dockerconfigjson -n openshift-config --confirm --to=./foo
  #ls -l ${WORKDIR}/.dockerconfigjson

  # merge a new entry into existing file
  oc registry login --registry="${IBM_CP_IMAGE_REGISTRY}" --auth-basic="cp:${IBM_ENTITLEMENT_KEY}" --to=${WORKDIR}/.dockerconfigjson
  #cat ${WORKDIR}/.dockerconfigjson

  # write back into cluster, but is better to save it to gitops repo :-)
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${WORKDIR}/.dockerconfigjson

  # TODO: Check if reboot is done automatically?

  # get back the yaml merged to save it in gitops git repo to be deploy with ArgoCD
  #oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${WORKDIR}/.dockerconfigjson  --dry-run=client -o yaml
}

init_sealed_secrets () {

  SEALED_SECRET_KEY_FILE=${SEALED_SECRET_KEY_FILE:-~/Downloads/sealed-secrets-ibm-demo-key.yaml}

  if [[ ! -f ${SEALED_SECRET_KEY_FILE} ]]; then
    echo "File Not Found: ${SEALED_SECRET_KEY_FILE}"
    echo "Please pass the environment variable SEALED_SECRET_KEY_FILE and make sure it points to an existing file"
    exit 1
  fi

  echo "Intializing sealed secrets with file ${SEALED_SECRET_KEY_FILE}"
  oc new-project sealed-secrets || true
  oc apply -f ${SEALED_SECRET_KEY_FILE}

}

ace_apps_bootstrap () {
  echo "Github user/org is ${GIT_ORG}"

  if [ -z ${GIT_USER} ]; then echo "Please set GIT_USER when running script"; exit 1; fi

  if [ -z ${GIT_TOKEN} ]; then echo "Please set GIT_TOKEN when running script"; exit 1; fi

  if [ -z ${GIT_ORG} ]; then echo "Please set GIT_ORG when running script"; exit 1; fi

  pushd ${OUTPUT_DIR}

  source gitops-3-apps/scripts/ace-bootstrap.sh

  popd

}

print_urls_passwords () {
    echo "Openshift Console UI: $(oc whoami --show-console)"
    echo " "
    echo "Openshift GitOps UI: $(oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}')"
    echo " "
    echo "To get the ArgoCD URL and admin password:"
    echo "-----"
    echo "oc get route -n openshift-gitops openshift-gitops-cntk-cluster -o template --template='https://{{.spec.host}}'"
    echo "oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=-"
    echo "-----"
}

# main

fork_repos


# Only applicable when workers reload automatically
# update_pull_secret

init_sealed_secrets

install_pipelines

install_argocd

#gen_argocd_patch

#patch_argocd

delete_default_argocd_instance

create_custom_argocd_instance

create_argocd_git_override_configmap

apply_argocd_git_override_configmap

argocd_git_override

deploy_bootstrap_argocd

# Setup of apps repo

if [[ "${CP_EXAMPLES}" == "true" ]]; then
  echo "Bootstrap Cloud Pak examples"

  ace_apps_bootstrap

fi

print_urls_passwords

exit 0



