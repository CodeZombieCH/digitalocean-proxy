#!/bin/bash

# A bash script to start and stop a disposable proxy
# on a DigitalOcean droplet
#
# Originally started by myself
# Further improved by ideas and snippets from
# https://gist.github.com/haf/7d80fc4527d4733aef0c

# Usage:
#   ./proxy-droplet.sh (start | stop | status)


# DigitalOcean API
DIGITALOCEAN_API="https://api.digitalocean.com/v2"


echoerr() { tput setaf 1; echo "$@" 1>&2; tput sgr0; }

exists() {
    # Check if droplet already exists
    EXISTING_DROPLETS=$(curl -s -X GET \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        "$DIGITALOCEAN_API/droplets?tag_name=temporary-proxy")

    DROPLET_COUNT=$(echo $EXISTING_DROPLETS | jq -r '.droplets | length')
    echo "Found $DROPLET_COUNT droplet(s)"
    if [ "$DROPLET_COUNT" -ne 0 ]; then return 1; else return 0; fi
}

single() {
    # Check if droplet already exists
    EXISTING_DROPLETS=$(curl -s -X GET \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        "$DIGITALOCEAN_API/droplets?tag_name=temporary-proxy")
    DROPLET_COUNT=$(echo $EXISTING_DROPLETS | jq -r '.droplets | length')
    [ "$DROPLET_COUNT" -eq 0 ] && echoerr "No droplet exists" && exit 1
    [ "$DROPLET_COUNT" -gt 1 ] && echoerr "More than one droplet exists" && exit 1

    DROPLET_ID=$(echo $EXISTING_DROPLETS | jq -r '.droplets[0].id')
    DROPLET_IP=$(echo $EXISTING_DROPLETS | jq -r '.droplets[0].networks.v4[0].ip_address')
    echo "Found droplet with ID $DROPLET_ID and IP $DROPLET_IP"
}

status() {
    exists
    if [ $? -ne 0 ]
    then
        echo 'Droplet exists'
    else
        echo 'Droplet does not exist'
    fi
}

start() {
    exists
    [ $? -ne 0 ] && echoerr "Droplet already exists" && exit 1

    # Lookup public key fingerprint
    FINGERPRINT=$(ssh-keygen -lf $SSH_KEY | cut -d ' ' -f 2)

    DROPLET_SPEC=$(jq ".ssh_keys[0] |= \"$FINGERPRINT\"" droplet-blueprint.json)

    # Create droplet
    curl -s -X POST \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DROPLET_SPEC" \
        "$DIGITALOCEAN_API/droplets" | jq '.' > proxy-droplet.json

    DROPLET_ID=$(jq -r '.droplet.id' proxy-droplet.json)

    [ -z "$DROPLET_ID" -o "$DROPLET_ID" == "null" ] && echoerr "Droplet creation failed" && exit 1

    echo "Successfully created droplet"
    echo "Droplet ID: $DROPLET_ID"


    # Query droplet IPv4 address
    echo -n "Polling 1min for droplet creation and IP to be assigned"
    i=0
    while [ $i -lt 60 ] ; do
        DROPLET_IP=$(curl -s -X GET \
            -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
            -H "Content-Type: application/json" \
            "$DIGITALOCEAN_API/droplets/$DROPLET_ID" | jq -r '.droplet.networks.v4[0].ip_address')
        [ -n "$DROPLET_IP" -a "$DROPLET_IP" != "null" ] && break
        echo -n '.'
        sleep 1s
        i=$((i + 1))
    done
    echo ''

    [ -z "$DROPLET_IP" ] && echoerr "Failed to retrieve droplet IP within 1m" && exit 1
    echo "Droplet IP: $DROPLET_IP"


    # Preparing SSH connection information
    read -d '' CONNECTION <<-EOF
-i $SSH_KEY
-o UserKnownHostsFile=/dev/null
-o StrictHostKeyChecking=no
root@$DROPLET_IP
EOF

    # Polling for SSH daemon to be ready
    echo -n "Polling for SSH daemon to be ready"
    until ssh -T -o ConnectTimeout=1 $CONNECTION exit 2>/dev/null
    do
        echo -n '.'
        sleep 1s
    done
    echo ''

    # Query your public IP address
    USER_IP=$(curl -s https://httpbin.org/ip | jq -r '.origin')
    [ -z "$USER_IP" ] && echoerr "Failed to detect your public IP" && exit 1
    echo "User public IP: $USER_IP"

    # Transfer user IP to proxy server by defining env variable
    echo 'Installing and setting up squid proxy...'
    ssh -T -o ConnectTimeout=1 $CONNECTION "USER_IP=$USER_IP bash -s" -- < ./droplet-init.sh
    echo 'Done'

    echo 'Verifying proxy is working...'
    DETECTED_IP=$(curl -s --proxy $DROPLET_IP:3128 https://httpbin.org/ip | jq -r '.origin')
    if [ -n "$DETECTED_IP" -a "$DETECTED_IP" != "$DROPLET_IP" ]
    then
        echoerr "Expected IP $DROPLET_IP, was $DETECTED_IP"
        exit 1
    fi
    echo 'Done'

    echo "==> Squid proxy is now available at: $DROPLET_IP:3128"
    echo 'Sample usage:'
    echo "curl --proxy $DROPLET_IP:3128 http://httpbin.org/ip"
}

stop() {
    single

    echo 'Deleting droplet...'
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        "$DIGITALOCEAN_API/droplets/$DROPLET_ID")

    [ "$STATUS" -ne 204 ] && echoerr "Failed to delete droplet" && exit 1
    echo 'Done'
}



# check env vars
[ -z "$DIGITALOCEAN_TOKEN" ] && echoerr "DIGITALOCEAN_TOKEN environment variable not defined" && exit 1
[ -z "$SSH_KEY" ] && echoerr "SSH_KEY environment variable not defined" && exit 1
[ ! -f "$SSH_KEY" ] && echoerr "SSH_KEY environment variable is not valid" && exit 1

# execute command
$1
