#!/bin/bash

# This script is executed on the virtual machine during the *Deployment* phase.
# It is used to apply parameters specific to the current deployment.
# It is executed secondly during a cloud deployement in IFB-Biosphere, after the *Installation* phase.

# General parameters
source /etc/profile.d/ifb.sh

# Selection of Jupyter stack
APP_IMG="ngsanalysisjupyter"
JUPYTER_STACK=$(ss-get --timeout=3 jupyter_stack)
#if [ -n "$JUPYTER_STACK" ]; then
#    APP_IMG="jupyter/${JUPYTER_STACK}"
#fi

# Launch JupyterLab instead of Jupyter Notebook
#JUPYTER_ENABLE_LAB=' '
JUPYTER_ENABLE_LAB='-e JUPYTER_ENABLE_LAB=yes'

# Self-signed certificate inside the container
APP_PORTS="-p 443:8888"
GEN_CERT='-e GEN_CERT=yes'

# Configure Proxy if required
if [ -n "$IFB_PROXY_ENABLED" ]; then
   echo IFB_PROXY_ENABLED
fi

# Docker volumes:
# 1. mydatalocal: from the system disk or ephemeral  one
IFB_DATADIR="/ifb/data/"
source /etc/profile.d/ifb.sh
VOL_NAME="mydatalocal"
VOL_DEV=$(readlink -f -n $IFB_DATADIR/$VOL_NAME )
DOCK_VOL=" --mount type=bind,src=$VOL_DEV,dst=$IFB_DATADIR/$VOL_NAME"

# 2. NFS mounts: from ifb_share configuration in autofs
IFS_ORI=$IFS
while IFS=" :" read VOL_NAME VOL_TYPE VOL_IP VOL_DEV ; do
        DOCK_VOL+=" --mount type=volume,volume-driver=local,volume-opt=type=nfs,src=$VOL_NAME,dst=$IFB_DATADIR/$VOL_NAME,volume-opt=device=:$VOL_DEV,volume-opt=o=addr=$VOL_IP"
done < /etc/auto.ifb_share
IFS=$IFS_ORI

## Run docker service
JUPYTER_TOKEN=$( openssl rand -hex 24 )
docker swarm init
SERVICE_ID=$( docker service create -d $APP_PORTS $DOCK_VOL $GEN_CERT $JUPYTER_ENABLE_LAB -e QT_QPA_PLATFORM='offscreen' $APP_IMG start-notebook.sh --NotebookApp.notebook_dir=$IFB_DATADIR --NotebookApp.token=$JUPYTER_TOKEN )

# Set service URLs
HOST_NAME=$( ss-get --timeout=3 hostname )
HTTP_ENDP="https://$HOST_NAME"
ss-set url.service "${HTTP_ENDP}"
ss-set ss:url.service "[HTTPS]${HTTP_ENDP},[JUPYTER_TOKEN]${JUPYTER_TOKEN}"
