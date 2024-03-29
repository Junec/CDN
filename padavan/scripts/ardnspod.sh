#!/bin/sh
#

#############################################################
# AnripDdns v6.0.0
#
# Dynamic DNS using DNSPod API
#
# Author: anrip<mail@anrip.com>, www.anrip.com/post/872
# Collaborators: ProfFan, https://github.com/ProfFan
#
# Usage: please refer to `ddnspod.sh`
#
#############################################################

# TokenID,Token

export arToken=""

# Get WAN-IP

arWanIp() {

    local hostIp

    local lanIps="^$"

    lanIps="$lanIps|(^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)"
    lanIps="$lanIps|(^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)"
    lanIps="$lanIps|(^169\.254\.[0-9]{1,3}\.[0-9]{1,3}$)"
    lanIps="$lanIps|(^172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3}$)"
    lanIps="$lanIps|(^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$)"

    case $(uname) in
        'Linux')
hostIp=$(wget --quiet --output-document=- http://members.3322.org/dyndns/getip)
        ;;
        'Darwin')
            hostIp=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | grep -Ev "$lanIps")
        ;;
    esac

    if [ -z "$hostIp" ]; then
        if type wget >/dev/null 2>&1; then
            hostIp=$(wget --quiet --output-document=- http://members.3322.org/dyndns/getip)
        else
            hostIp=$(curl -s http://members.3322.org/dyndns/getip)
        fi
    fi

    echo $hostIp

}

# Dnspod Bridge
# Arg: type data

arDdnsApi() {

    local agent="AnripDdns/6.0.0(mail@anrip.com)"

    local apiurl="https://dnsapi.cn/${1:?'Info.Version'}"
    local params="login_token=$arToken&format=json&$2"

    #if type wget >/dev/null 2>&1; then
    #    wget --quiet --no-check-certificate --output-document=- --user-agent=$agent --post-data $params $apiurl
    #else
    #    curl -s -A $agent -d $params $apiurl
    #fi
    curl -k -s -A $agent -d $params $apiurl

}

# Fetch Domain Ip
# Arg: domain

arDdnsInfo() {

    local domainId
    local recordId
    local recordIp

    # Get domain ID
    domainId=$(arDdnsApi "Domain.Info" "domain=$1")
    domainId=$(echo $domainId | sed 's/.*"id":"\([0-9]*\)".*/\1/')

    # Get Record ID
    recordId=$(arDdnsApi "Record.List" "domain_id=$domainId&sub_domain=$2&record_type=A")
    recordId=$(echo $recordId | sed 's/.*"id":"\([0-9]*\)".*/\1/')

    # Last IP
    recordIp=$(arDdnsApi "Record.Info" "domain_id=$domainId&record_id=$recordId")
    recordIp=$(echo $recordIp | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/')

    # Output IP
    case "$recordIp" in
        [1-9]*)
            echo $recordIp
            return 0
        ;;
        *)
            echo "Get Record Info Failed!"
            return 1
        ;;
    esac

}

# Update Domain Ip
# Arg: main-domain sub-domain

arDdnsUpdate() {

    local domainId
    local recordId
    local recordRs
    local recordIp
    local recordCd

    local hostIp=$(arWanIp)

    # Get domain ID
    domainId=$(arDdnsApi "Domain.Info" "domain=$1")
    domainId=$(echo $domainId | sed 's/.*"id":"\([0-9]*\)".*/\1/')

    # Get Record ID
    recordId=$(arDdnsApi "Record.List" "domain_id=$domainId&sub_domain=$2&record_type=A")
    recordId=$(echo $recordId | sed 's/.*"id":"\([0-9]*\)".*/\1/')

    # Update IP
    recordRs=$(arDdnsApi "Record.Ddns" "domain_id=$domainId&record_id=$recordId&sub_domain=$2&record_type=A&value=$hostIp&record_line=%e9%bb%98%e8%ae%a4")
    recordIp=$(echo $recordRs | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/')
    recordCd=$(echo $recordRs | sed 's/.*{"code":"\([0-9]*\)".*/\1/')

    # Output IP
    if [ "$recordIp" = "$hostIp" ]; then
        if [ "$recordCd" = "1" ]; then
            #logger -t "dnspod" $recordIp
            return 0
        fi
        # Echo error message
        logger -t "dnspod" $recordRs | sed 's/.*,"message":"\([^"]*\)".*/\1/'
        return 1
    else
        logger -t "dnspod" "Update Failed! Please check your network."
        return 1
    fi

}

# DDNS Check
# Arg: Main Sub
arDdnsCheck() {

    local postRs
    local lastIP

    local hostIp=$(arWanIp)

    logger -t "dnspod" "Updating Domain: $2.$1"
    logger -t "dnspod" "Host Ip: $hostIp"

    lastIP=$(arDdnsInfo "$1" "$2")
    if [ $? -eq 0 ]; then
        logger -t "dnspod" "Last IP: $lastIP"
        if [ "$lastIP" != "$hostIp" ]; then
            postRs=$(arDdnsUpdate "$1" "$2")
            if [ $? -eq 0 ]; then
                logger -t "dnspod" "Update Success."
                return 0
            else
                logger -t "dnspod" "Update Failed."
                return 1
            fi
        fi
        logger -t "dnspod" "Last IP is the same as current IP!"
        return 1
    fi

    logger -t "dnspod" "$lastIP"
    return 1

}
arToken="xxx,xxx"

# Place each domain you want to check as follows
# you can have multiple arDdnsCheck blocks
arDdnsCheck "xxx.com" "tl"


