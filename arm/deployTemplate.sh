#!/usr/bin/env bash

###################################################################################################
# Script Name: deployTemplate.sh 
# Author: Jungho Kim
# Description: Validates then deploys an ARM template.  It will look for an azureDeploy.json and 
# azureDeploy.parameters.json then validate it and if valid, deploy it.  
#
# Options:
# 
# -g <resourceGroup>
# -n <deploymentName>
# -v if provided will only validate not deploy
#
#######################################################################################################
resourceGroup=''
deploymentName=''
template='azureDeploy.json'
parameters='azureDeploy.parameters.json'
justValidate=false


function usage {
    echo "To validate and deploy:  ./deployTemplate.sh -g <resourceGroup> -n <deploymentName>"
    echo "To just validate: add the -v switch"
}

function validate_template {
    echo "start validating template..."

    azure group template validate -g "${resourceGroup}" -f "$template" -e "${parameters}"

    if [ $? -ne 0 ]; then
        echo "Template validation failed.  See error."
        exit 1
    else
        echo "template is valid."
    fi
}

function deploy_template {
    if ! $justValidate 
    then
        echo "start deploying template..."
        azure group deployment create -f "${template}" -e "$parameters" -g "${resourceGroup}" -n "${deploymentName}"
    fi

    if [ $? -ne 0 ]; then 
        echo "deployment failed.  Check error messages."
        exit 1;
    fi
}

while getopts g:n:v opt; do
    case $opt in
        g)
            resourceGroup=${OPTARG}
            echo "resourceGroup --> $resourceGroup" 
            ;;
        n) 
            deploymentName=${OPTARG}
            echo "deploymentName --> $deploymentName"
            ;;
        v) #if true just validate and don't deploy'
            justValidate=true; 
            echo "validation only set to ${justValidate}"
            ;;
        \?) #invalid option
            echo "${OPTARG} is not a valid option"
            usage
            exit 1
            ;;
    esac 
done

if [ -z "$resourceGroup" ] ;then echo "-g must be provided"; exit 1; fi
if [ -z "$deploymentName" ] ;then echo "-n must be provided"; exit 1; fi 

validate_template
deploy_template

exit 0

