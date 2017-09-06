#!/usr/bin/env bash

######################################################################################################
# Script Name: configureSshAndAnsible.sh 
# Author: Jungho Kim
# Description: Configures the VMs with ssh authentication and installs ansible on the control and target hosts.
#  This version is only supported on debian distributions.
#
# Options:
# 
# -u <adminUserName>
# -k <sshPubKey>
# -t <control | target>         the type of the host
# -f <playbooks file>           required if -t is control
# -p <sshPrivateKey>            required if -t is control
#
# if -t is control then all are required
# if -t is target then only u, k are required 
#
# See the 'commandBase', 'controlHostCommand', 'targetHostCommand' variables in azureDeploy.json
#
#######################################################################################################

function log {
    echo "configureSshAndAnsible.sh --> $*"
}

function usage {
    log "Usage: IF -t is 'target' --> configureSshAndAnsible.sh -t target -u adminUserName -k sshPubKey"
    log "Usage: IF -t is 'control' --> configureSshAndAnsible.sh -t control -u adminUserName -k sshPubKey -p sshPubKey -f playbooks_file"  
}

function validate_parameters {
    # these must be provided regardless of the type of host
    if [ -z "$host_type" ] ;then log "-t must be provided"; exit 1; fi
    if [ -z "$user" ] ;then log "-u must be provided"; exit 1; fi 
    if [ -z "$public_key_file" ] ;then log "-k must be provided"; exit 1; fi

    if [ "$host_type" == "control" ] 
    then
        if [ -z "$private_key_file" ] ;then log "-t was $host_type,  value for -p must be provided."; exit 1; fi
        if [ -z "$playbooks_file" ] ;then log "-t was $host_type, value for -f must be provided."; exit 1; fi
    fi
}

function configure_ssh {
    if [ "$host_type" == "control" ]
    then
        configure_control_ssh
    else
        configure_target_ssh
    fi
}

function configure_target_ssh {
    if [ -f "$public_key_file" ] 
    then
        log "installing public key to /home/${user}/.ssh/authorized_keys"
        cat "$public_key_file" >> /home/"${user}"/.ssh/authorized_keys;
        rm "$public_key_file"
        chmod 700 /home/"${user}"/.ssh
        chmod 600 /home/"${user}"/.ssh/authorized_keys
        
        log "public key deployed, restarting ssh..."
        
        service ssh restart
        
        log "ssh restarted."
    else
        log "$public_key_file was not found in the current directory.  exiting."
        exit 1
    fi
}


function configure_control_ssh {
    configure_target_ssh

    if [ -f "$private_key_file" ]
    then
        log "installing the private key to /home/${user}/.ssh/"
        
        cat "${private_key_file}" >> /home/"${user}"/.ssh/"${private_key_file}"
        rm "${private_key_file}"

        log "private key deployed, restarting ssh."
        
        chmod 700 /home/"${user}"/.ssh
        service ssh restart
        
        log "ssh restarted."
    else
        log "$private_key_file was not found in the current directory.  exiting."
        exit 1
    fi
}

function install_ansible {

    if [ "$host_type" == "control" ]
    then
        log "installing ansible..."
        #the --yes switch is important otherwise, the shell will wait for a response from the user and hang.

        if [ -f /etc/centos-release ]; then
            log "distribution is $(cat /etc/centos-release)"
            sudo yum install epel-release -y 
            sudo yum install ansible -y
        fi

        if [ -f /etc/lsb-release ] 
        then
            DISTRO=$(cat < /etc/lsb-release | grep '^DISTRIB_ID' | awk -F= '{ print $2 }')

            if [ "$DISTRO" == 'Ubuntu' ]
            then
                log "distribution is Ubuntu."
                apt-get --yes install sofware-properties-common
                apt-add-repository --yes ppa:ansible/ansible 
                apt-get --yes update 
                apt-get --yes install ansible
            fi
        fi 

        if [ $? -ne 0 ]; then
            log "Failed to install ansible."
            exit 1
        fi

        log "ansible installed in $(which ansible)"

        if [ -f "$playbooks_file" ]
        then
            log "moving ${playbooks_file} to /home/${user}/"
            mv "${playbooks_file}" /home/"${user}"/
            chmod 777 /home/"${user}"/"${playbooks_file}"
        else
            log "${playbooks_file} was not found."
            exit 1
        fi
    fi
}

host_type=''
user=''
public_key_file=''
private_key_file=''
playbooks_file=''

log "$# options and arguments were passed."

while getopts u:t:k:p:f: opt; do
    case $opt in
        u)
            user=${OPTARG}
            log "user --> $user" 
            ;;
        t) 
            host_type=${OPTARG}
            log "host_type --> $host_type"
            ;;
        k)
            public_key_file=${OPTARG}
            log "public_key_file --> $public_key_file"
            ;;
        p) 
            private_key_file=${OPTARG}
            log "private_key_file --> $private_key_file"
            ;;
        f)
            playbooks_file=${OPTARG}
            log "playbooks_file --> $playbooks_file"
            ;;
        \?) #invalid option
            log "${OPTARG} is not a valid option"
            usage
            exit 1
            ;;
    esac 
done

validate_parameters
#configure_ssh
install_ansible

