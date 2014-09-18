#!/bin/sh
for OSD_ID in `ps -aux | grep ceph-osd | awk '{print $14}'`
do
  sudo stop ceph-osd id=$OSD_ID
  sudo ceph osd out $OSD_ID
  sudo ceph osd crush remove osd.$OSD_ID
  sudo ceph auth del osd.$OSD_ID
  sudo ceph osd rm $OSD_ID
  sudo rm -rf /var/local/osd-$OSD_ID
done

sudo rm -rf /var/lib/ceph/osd/*
