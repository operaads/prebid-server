#!/usr/bin/env bash

progname=$0
scriptDir=$(dirname ${progname})

print_help() {
    echo "
This script is to:
    1) run unit tests
    2) go build a given service
    3) build docker image
    4) push docker image to Opera docker repo

Usage:
    ${progname} -s <service> [--test] [--push]

    -s <service>: assign service name, replace <service> to adserver or adtracker
    --test: run unit tests
    --push: push the docker image to opera docker repo
    --deploy: deploy the docker image to k8s, only works with --test and --push together

Examples:
    ${progname} -s adserver
    ${progname} -s adserver --push
    ${progname} -s adserver --test --push
    ${progname} -s adtracker
    ${progname} -s adtracker --push
    ${progname} -s adtracker --test --push
    ${progname} -s bidding-kit-server --test --push --java
"
}

error_exit() {
    echo "Error: $1"; exit 1
}
ut=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) print_help; exit 0;;
        --push)    push=1; shift 1;;
        --test)    test=1; shift 1;;
        --ut)      ut=true;shift 1;;
        --repo)    repo=$2; shift 2;;
        --user)    user=$2; shift 2;;
        --pass)    pass=$2; shift 2;;
        --) shift; break;;
        *) echo "Internal error: option processing error: $1" 1>&2;  exit 1;;
    esac
done

service="prebid-server"

image_name=${repo}/${service}

service_ver=1.0

build_number="${BUILD_NUMBER:-0}" # Jenkins build number or 0
git_hash=`git log -1 --pretty=%h`
full_version=${service_ver}.${build_number}.${git_hash}
image_tag=${full_version}

confName="test.yml"
if [[ ${test} ]]; then
    image_tag=test.${image_tag}
    confName="test.yml"
else
    image_tag=prod.${image_tag}
    confName="pro.yml"
fi

echo -e "\n====== Build docker image ======"

docker build -t ${image_name}:${image_tag} -t ${image_name}:latest --build-arg version=${full_version} --build-arg TEST=${ut} --build-arg configName=${confName} -f Dockerfile . || error_exit "docker build error"
echo "<section><field name=\"Image\">${image_name}</field><field name=\"Tag\">${image_tag}</field></section>" > report.xml

if [[ ${push} ]]; then
    echo -e "\n====== Upload docker image ======"
    docker login -u=${user} -p=${pass} ${repo} || error_exit "docker login error"
    docker push ${image_name}:${image_tag} || error_exit "docker push ${image_name}:${image_tag} error"
    docker push ${image_name}:latest || error_exit "docker push ${image_name}:latest error"
fi


echo -e "\n====== Done ======"
