#!/bin/bash 
source ~/admin-openrc.sh

echo "############### STARTING MIGRATION ##############"

# ---------------------------------------------------------------------------+
#------name of the instance--------------------------------------------------|
vm_name=251116
#-------department you want the instance to migrate in-----------------------|
department_name=POCSERVERS
#--------source directory of migration files---------------------------------|
directory=/source/SDCAPOC-VM-172.19.251.116
#-----------vmware filename without the extension----------------------------|
filename=SDCAPOC-VM-172.19.251.116
#-----------hostname of v2v appliance(as on sysadmin dashboard)--------------|
v2v_hostname=v2v_1
#------------flavor for instance---------------------------------------------|
flavor=2cpu_4g_105g
#------------os type- linux or windows---------------------------------------|
ostype=linux
#-------od dist - windows or centos or ubuntu or cirros or rhel -------------|
osdist=rhel
#--------image_name to be taken from "openstack image list"------------------|
image_name=Centos-7
#--------image_id to be the taken from "openstack image list"----------------|
image_id=3cc069b5-c67c-4b2b-9ad5-f5bed9362113
#-------number of total disks in the instance--------------------------------|
disks=1
#----------------------------------------------------------------------------|
# ---------------------------------------------------------------------------+

# ***************************************************************#################################******************************************************************************
# ***************************************************************#################################******************************************************************************

echo
echo "############### VARIABLES EXPORTED ############################"
echo
echo "############### GETTING V2V APPLIANCE ID ############################"
echo

dt=`date '+%d%m%Y_%H:%M:%S'`
v2v_id="$(openstack server list --all-projects | grep -i $v2v_hostname | awk '{ print $2 }')"

echo "############### GOT V2V APPLIANCE ID ############################"
echo


conversion () {


export OS_PROJECT_NAME=$department_name
chmod -R 777 $directory
chown -R root:root $directory
export LIBGUESTFS_BACKEND=direct
echo
echo "############### STARTING CONVERSION ############################"
echo
virt-v2v -x -x -i vmx $directory/*.vmx -o openstack -oo server-id=$v2v_id
echo
echo "############### VM HAS BEEN CONVERTED #######################"
echo
}

server_create () {
echo
echo "#################### CREATING SERVER ###################"
export OS_PROJECT_NAME=$department_name
vol_name="$(openstack volume list | grep ${filename}-sda | awk '{print $4}')"
vol_id="$(openstack volume list | grep ${filename}-sda | awk '{print $2}')"
openstack server create --volume $vol_name --flavor $flavor --network ${department_name}_network  $vm_name


sleep 5
echo
echo "################### SERVER HAS BEEN CREATED ##################"
openstack server show $vm_name

echo
echo "############### PLEASE TEST IF THE INSTANCE IS BOOTING ############################"
echo
echo "############### FOR WINDOWS VM, PLEASE CONFIGURE THE VIRTIO CONTROLLER ############################"
echo
read -p "###################### IS THE CONFIGURATION DONE (yes/no)?###################### " CONT
if [[  "$CONT" =~ [yY][eE][sS]|[yY] ]]
then
	    echo
	    echo "############### GOOD FOR YOU ###########################"
	    echo
elif [[  "$CONT" =~ [nN][oO]|[nN] ]]
then
	exit 4
else
	exit 4
fi


echo
echo "################### DELETING SERVER ####################"
openstack server delete $vm_name
echo "############### UPDATING IMAGE METADATA  ############################"
sleep 10
cinder image-metadata $vol_id unset hw_cpu_cores os_distro os_version hypervisor_type hw_vif_model hw_disk_bus hw_cpu_sockets hw_machine_type architecture hw_rng_model vm_mode os_type hw_video_model

cinder image-metadata $vol_id set hw_qemu_guest_agent=yes hw_video_model=qxl hw_video_ram=128 hw_rng_model=virtio hw_scsi_model=virtio-scsi hw_disk_bus=scsi os_require_quiesce=yes container_format=bare disk_format=raw min_ram=0 min_disk=0 os_distro=$osdist os_type=$ostype hw_machine_type=q35 hw_cdrom_bus=sata image_name=$image_name image_id=$image_id
echo
echo "################ IMAGE METADATA HAS BEEN UPDATED ##################"
openstack server create --volume $vol_name --flavor $flavor --network ${department_name}_network  $vm_name
echo
echo "######################## CREATING SERVER AGAIN #################"
echo
read -p "###################### IS THE INSTANCE WORKING (yes/no)?###################### " CONT
if [[  "$CONT" =~ [yY][eE][sS]|[yY] ]]
then
	    echo
	    echo "############### GOOD FOR YOU ###########################"
	    echo
elif [[  "$CONT" =~ [nN][oO]|[nN] ]]
then
	echo "############### DELETING SERVER ############"
	echo
	openstack server delete $vm_name
	echo
	sleep 10
	echo "#################### UNSETTING METADATA ################"
	cinder image-metadata $vol_id unset hw_machine_type
	echo
	echo "################### CREATING SERVER #################"
	openstack server create --volume $vol_name --flavor $flavor --network ${department_name}_network  $vm_name
	echo
	echo "############## SERVER HAS BEEN CREATED ##############"

else
	exit 4
fi
#for loop for disks
if [[ $disks == 1 ]]
then
	echo "############## NO ADDITIONAL DISKS #################"

elif [[ $disks == 2 ]]
then 
	echo "#################### ADDING ADDITIONAL DISK ####################"
	vol_id1="$(openstack volume list | grep ${filename}-sdb | awk '{print $2}')"
	openstack server add volume $vm_name $vol_id1
	echo "################### ADDITION DONE ########################"
elif [[ $disks == 3 ]]
then
	echo "######################### ADDING ADDITIONAL DISKS #################"
	vol_id1="$(openstack volume list | grep ${filename}-sdb | awk '{print $2}')"
	vol_id2="$(openstack volume list | grep ${filename}-sdc | awk '{print $2}')"
	openstack server add volume $vm_name $vol_id1
	openstack server add volume $vm_name $vol_id2
	echo "################### ADDITION DONE ########################"

else
	exit 4
fi

}

stack_adopt () {
echo
echo "############### GRABBING INSTANCE DETAILS #################"
echo
export OS_PROJECT_NAME=$department_name
vol_name="$(openstack volume list | grep ${filename}-sda | awk '{print $4}')"
vol_id="$(openstack volume list | grep ${filename}-sda | awk '{print $2}')"
vol_size="$(openstack volume list | grep ${filename}-sda | awk '{print $8}')"
vol_name1="$(openstack volume list | grep ${filename}-sdb | awk '{print $4}')"
vol_id1="$(openstack volume list | grep ${filename}-sdb | awk '{print $2}')"
vol_size1="$(openstack volume list | grep ${filename}-sdb | awk '{print $8}')"
vol_name2="$(openstack volume list | grep ${filename}-sdc | awk '{print $4}')"
vol_id2="$(openstack volume list | grep ${filename}-sdc | awk '{print $2}')"
vol_size2="$(openstack volume list | grep ${filename}-sdc | awk '{print $8}')"
stack_id="$(openstack stack list | grep -w $department_name | awk '{print $2}' | head -n 1)"
instance_id="$(openstack server show $vm_name | grep id | awk 'NR==1{print $4}')"
flavor="$(openstack server show $vm_name | grep flavor | awk '{print $4}')"
port_ip="$(openstack server show $vm_name | grep addresses | awk 'NR==1{print $4}' | tr -d "${department_name}_network=")"
port_mac="$(openstack port list | grep ${port_ip} | awk '{print $5}')"
port_id="$(openstack port list | grep ${port_ip} | awk '{print $2}')"

echo
echo "############### INSTANCE DETAILS EXPORTED ############################"
echo


cd /root/adopt/
openstack stack abandon --output-file ${department_name}.json $stack_id
#prompt or while loop
echo "yes" | cp -r ${department_name}.json /root/adopt/templates/dynamic/base.json

echo
echo "############# STACK HAS BEEN ABANDONED ####################"
echo
#for loop
if [[ $disks == 1 ]]
then
	cat > config.yaml <<EOL
#Boot-Volume-Details                                               
#
v2v: "yes"                                                      # specify whether the instance was migrated with direct v2v
boot-vol-snapshot-id: "none"    #id of the snapshot from which boot volume created, if v2v this value is none
boot-vol-size: $vol_size                                               #size of the boot volume
boot-vol-type: "SSD_cached_HDD"                                           # type of the boot volume
boot-vol-id: "$vol_id"             # id of the boot volume
#
#Public/Provider IP details
#
is-public-ip: "no"                                             # whether vm has public ip or not
provider-network: "public_provider_1"                           # name of the network for the public ip
public-port-id: "110b6b6d-ceb0-4f47-a641-69e2045e48e1"          # id of the public ip port
public-mac-address: "fa:16:3e:90:6d:b1"                         # mac address of the public ip port
#
#Private IP details
#
is-private-ip: "yes"                                             # whether vm has private ip or not
private-port-id: "$port_id"         # id of the pivate ip port
private-mac-address: "$port_mac"                        # mac address of the private ip port
#
#Instance details
#
flavour-name: "$flavor"                                    # name of flavour assigned to vm
instance-name: "$vm_name"                                        # name of the vm
instance-id: "$instance_id"              # id of the vm
boot-vol-device-id: "vda"                                       # the drive name on which boot volume is attached
department-name: "$department_name"                                           # name of the project on which stack need to be adopted
#
#Additional volume details
#
#We are using lists for additional volume data if there is more than one additional volume
#Add entries to the list according to the no of volumes
is-additional-vol: "no"                                        # whether additional volume is attached to vm
no-of-additional-vols: 1                                        #Count of the additionals volumes attached to the instance.

add-vol-name: ["SFTLVDI-VM-172.19.248.107-sdb"]                                      # name of the additional volume
add-vol-size: [40]                                                # size of the additional volume
add-vol-type: ["SSD_cached_HDD"]                                            # type of the additional volume
add-vol-id: ["e2541948-b290-4128-881a-5951c0f4b19a"]              # id of the additional volume

#
#Floating IP details.
#
is-floating-ip: "no"                                            # whether floating ip is attached to vm
float-ip-id: "68a5d1b5-54b5-465c-bf32-c151c6d55371"             # device id of the floating ip port
float-nw-id: "1268681b-3e1b-4e3e-bf0c-bfcdc84bf6f8"             # network id from which floating ip is created
float-ip: "10.11.12.175"                                        # floating ip

# floating ip resource id > Device ID of the floating ip port in provider n/w

EOL


elif [[ $disks == 2 ]]
then
	cat > config.yaml <<EOL
#Boot-Volume-Details                                               
#
v2v: "yes"                                                      # specify whether the instance was migrated with direct v2v
boot-vol-snapshot-id: "none"    #id of the snapshot from which boot volume created, if v2v this value is none
boot-vol-size: $vol_size                                               #size of the boot volume
boot-vol-type: "SSD_cached_HDD"                                           # type of the boot volume
boot-vol-id: "$vol_id"             # id of the boot volume
#
#Public/Provider IP details
#
is-public-ip: "no"                                             # whether vm has public ip or not
provider-network: "public_provider_1"                           # name of the network for the public ip
public-port-id: "110b6b6d-ceb0-4f47-a641-69e2045e48e1"          # id of the public ip port
public-mac-address: "fa:16:3e:90:6d:b1"                         # mac address of the public ip port
#
#Private IP details
#
is-private-ip: "yes"                                             # whether vm has private ip or not
private-port-id: "$port_id"         # id of the pivate ip port
private-mac-address: "$port_mac"                        # mac address of the private ip port
#
#Instance details
#
flavour-name: "$flavor"                                    # name of flavour assigned to vm
instance-name: "$vm_name"                                        # name of the vm
instance-id: "$instance_id"              # id of the vm
boot-vol-device-id: "vda"                                       # the drive name on which boot volume is attached
department-name: "$department_name"                                           # name of the project on which stack need to be adopted
#
#Additional volume details
#
#We are using lists for additional volume data if there is more than one additional volume
#Add entries to the list according to the no of volumes
is-additional-vol: "no"                                        # whether additional volume is attached to vm
no-of-additional-vols: 1                                        #Count of the additionals volumes attached to the instance.

add-vol-name: ["$vol_name1"]                                      # name of the additional volume
add-vol-size: [$vol_size1]                                                # size of the additional volume
add-vol-type: ["SSD_cached_HDD"]                                            # type of the additional volume
add-vol-id: ["$vol_id1"]              # id of the additional volume

#
#Floating IP details.
#
is-floating-ip: "no"                                            # whether floating ip is attached to vm
float-ip-id: "68a5d1b5-54b5-465c-bf32-c151c6d55371"             # device id of the floating ip port
float-nw-id: "1268681b-3e1b-4e3e-bf0c-bfcdc84bf6f8"             # network id from which floating ip is created
float-ip: "10.11.12.175"                                        # floating ip

# floating ip resource id > Device ID of the floating ip port in provider n/w

EOL


elif [[ $disks == 3 ]]
then
	cat > config.yaml <<EOL
#Boot-Volume-Details                                               
#
v2v: "yes"                                                      # specify whether the instance was migrated with direct v2v
boot-vol-snapshot-id: "none"    #id of the snapshot from which boot volume created, if v2v this value is none
boot-vol-size: $vol_size                                               #size of the boot volume
boot-vol-type: "SSD_cached_HDD"                                           # type of the boot volume
boot-vol-id: "$vol_id"             # id of the boot volume
#
#Public/Provider IP details
#
is-public-ip: "no"                                             # whether vm has public ip or not
provider-network: "public_provider_1"                           # name of the network for the public ip
public-port-id: "110b6b6d-ceb0-4f47-a641-69e2045e48e1"          # id of the public ip port
public-mac-address: "fa:16:3e:90:6d:b1"                         # mac address of the public ip port
#
#Private IP details
#
is-private-ip: "yes"                                             # whether vm has private ip or not
private-port-id: "$port_id"         # id of the pivate ip port
private-mac-address: "$port_mac"                        # mac address of the private ip port
#
#Instance details
#
flavour-name: "$flavor"                                    # name of flavour assigned to vm
instance-name: "$vm_name"                                        # name of the vm
instance-id: "$instance_id"              # id of the vm
boot-vol-device-id: "vda"                                       # the drive name on which boot volume is attached
department-name: "$department_name"                                           # name of the project on which stack need to be adopted
#
#Additional volume details
#
#We are using lists for additional volume data if there is more than one additional volume
#Add entries to the list according to the no of volumes
is-additional-vol: "no"                                        # whether additional volume is attached to vm
no-of-additional-vols: 1                                        #Count of the additionals volumes attached to the instance.

add-vol-name: ["$vol_name1"]                                      # name of the additional volume
add-vol-size: [$vol_size1]                                                # size of the additional volume
add-vol-type: ["SSD_cached_HDD"]                                            # type of the additional volume
add-vol-id: ["$vol_id1"]              # id of the additional volume


add-vol-name: ["$vol_name2"]                                      # name of the additional volume
add-vol-size: [$vol_size2]                                                # size of the additional volume
add-vol-type: ["SSD_cached_HDD"]                                            # type of the additional volume
add-vol-id: ["$vol_id2"]              # id of the additional volume

#
#Floating IP details.
#
is-floating-ip: "no"                                            # whether floating ip is attached to vm
float-ip-id: "68a5d1b5-54b5-465c-bf32-c151c6d55371"             # device id of the floating ip port
float-nw-id: "1268681b-3e1b-4e3e-bf0c-bfcdc84bf6f8"             # network id from which floating ip is created
float-ip: "10.11.12.175"                                        # floating ip

# floating ip resource id > Device ID of the floating ip port in provider n/w

EOL

	        
fi
echo "yes" | cp -r  /root/adopt/build/* /root/adopt/${dt}.json
rm -rf /root/adopt/build/*
python adopt.py


read -p "##################### (yes/no)?###################### " CONT
if [[  "$CONT" =~ [yY][eE][sS]|[yY] ]]
then

	export OS_PROJECT_NAME=$department_name
	cd /root/adopt/build/
	openstack stack adopt --adopt-file ${department_name}.json $department_name

	echo
	echo "############## STACK HAS BEEN ADOPTED BACK ###############"
	echo
	echo
	echo "############### GOOD FOR YOU ###########################"
	echo

elif [[  "$CONT" =~ [nN][oO]|[nN] ]]
then
	
	export OS_PROJECT_NAME=$department_name
	cd /root/adopt/
	openstack stack adopt --adopt-file ${department_name}.json $department_name


	echo
	echo "############## STACK HAS BEEN ADOPTED BACK ###############"
	echo

else
	exit 4

fi


}


$1

