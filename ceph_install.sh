CEPH_DIR=$1
CEPH_DIR=${CEPH_DIR:-${CEPH_DIR:-/etc/ceph}}

# get rid of process and directories leftovers
sudo stop ceph-mon id=$(hostname) || true
sudo stop ceph-osd id=0
sudo stop ceph-osd id=1

sudo umount /dev/sdb
sudo umount /dev/sdc
sudo rm -rf /var/lib/ceph

#Check for existence of Ceph package, install if not present
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ceph|grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    wget -q -O- 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | sudo apt-key add -
    echo deb http://ceph.com/packages/ceph-extras/debian $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph-extras.list
    sudo apt-add-repository 'deb http://ceph.com/debian-firefly/ trusty main'i
    sudo apt-get update
    sudo apt-get --yes install ceph ceph-common
fi

if [ -d $CEPH_DIR ]; then
   sudo rm -rf $CEPH_DIR
   sudo mkdir $CEPH_DIR
else
   sudo mkdir $CEPH_DIR
fi

CLUSTER_NAME=ceph
UUID=$(uuidgen)
IP_ADDR=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
#Populate Ceph conf
echo "
[global]
fsid = $UUID
mon initial members = $(hostname)
mon host = $IP_ADDR 
auth service required = cephx
auth client required = cephx
osd journal size = 1024
filestore xattr use omap = true
osd pool default size = 2
osd pool default min size = 1
osd pool default pg num = 333
osd pool default pgp num = 333
osd crush chooseleaf type = 0" | sudo tee /etc/ceph/ceph.conf

#Create a monitor

sudo ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring

sudo monmaptool --create --add $(hostname)  $IP_ADDR --fsid $UUID /tmp/monmap

if [ -d "/var/lib/ceph/mon" ]; then
    sudo rm -rf  /var/lib/ceph/mon
    sudo mkdir -p /var/lib/ceph/mon/$CLUSTER_NAME-$(hostname)
else
    sudo mkdir -p /var/lib/ceph/mon/$CLUSTER_NAME-$(hostname) 
fi 

sudo ceph-mon --mkfs -i $(hostname) --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
sudo start ceph-mon id=$(hostname)


#Add OSDs

#ADD first OSD
OSD0_ID=$(sudo ceph osd create)

if [ -d "/var/lib/ceph/osd" ]; then
    sudo rm -rf  /var/lib/ceph/osd
    sudo mkdir -p /var/lib/ceph/osd/$CLUSTER_NAME-$OSD0_ID
else
   sudo mkdir -p /var/lib/ceph/osd/$CLUSTER_NAME-$OSD0_ID
fi

sudo mkfs -t xfs -f /dev/sdb
sudo mount /dev/sdb /var/lib/ceph/osd/$CLUSTER_NAME-$OSD0_ID

sudo  ceph-osd -i $OSD0_ID --mkfs --mkkey
sudo ceph auth add osd.$OSD0_ID osd 'allow *' mon 'allow profile osd' -i /var/lib/ceph/osd/$CLUSTER_NAME-$OSD0_ID/keyring

sudo ceph osd crush add-bucket $(hostname) host
sudo ceph osd crush move $(hostname) root=default
sudo ceph osd crush add osd.$OSD0_ID 1.0 host=$(hostname)
sudo start ceph-osd id=$OSD0_ID

#ADD Second OSD
OSD1_ID=$(sudo ceph osd create)

sudo mkdir -p /var/lib/ceph/osd/$CLUSTER_NAME-$OSD1_ID

sudo mkfs -t xfs -f /dev/sdc
sudo mount /dev/sdc /var/lib/ceph/osd/$CLUSTER_NAME-$OSD1_ID

sudo  ceph-osd -i $OSD1_ID --mkfs --mkkey
sudo ceph auth add osd.$OSD1_ID osd 'allow *' mon 'allow profile osd' -i /var/lib/ceph/osd/$CLUSTER_NAME-$OSD1_ID/keyring

sudo ceph osd crush move $(hostname) root=default
sudo ceph osd crush add osd.$OSD1_ID 1.0 host=$(hostname)
sudo start ceph-osd id=$OSD1_ID
