#!/bin/sh
CLUSTER_NAME=ceph

for var in $(seq 0 4)
do
  OSD_ID=$(sudo ceph osd create)
  sudo mkdir -p /var/local/osd-$OSD_ID
  if [ -d "/var/lib/ceph/osd" ]; then
    sudo rm -rf  /var/lib/ceph/osd/$CLUSTER_NAME-$OSD_ID
    sudo mkdir -p /var/lib/ceph/osd/$CLUSTER_NAME-$OSD_ID
  else
   sudo mkdir -p /var/lib/ceph/osd/$CLUSTER_NAME-$OSD_ID
  fi

  sudo mkfs -t xfs -f /var/local/osd-$OSD_ID
  sudo mount /var/local/osd-$OSD_ID /var/lib/ceph/osd/$CLUSTER_NAME-$OSD_ID

  sudo  ceph-osd -i $OSD_ID --mkfs --mkkey
  sudo ceph auth add osd.$OSD_ID osd 'allow *' mon 'allow profile osd' -i /var/lib/ceph/osd/$CLUSTER_NAME-$OSD_ID/keyring

  sudo ceph osd crush add-bucket $(hostname) host
  sudo ceph osd crush move $(hostname) root=default
  sudo ceph osd crush add osd.$OSD_ID 1.0 host=$(hostname)
  sudo start ceph-osd id=$OSD_ID

done
