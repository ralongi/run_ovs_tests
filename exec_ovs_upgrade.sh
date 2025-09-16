#!/bin/bash

# ovs_upgrade

pushd ~/temp
wget -O ~/fdp_package_list.sh http://netqe-infra01.knqe.eng.rdu2.dc.redhat.com/share/misc/fdp_package_list.sh

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
LEAPP_UPGRADE=${LEAPP_UPGRADE:-"no"}
#leapp_upgrade_repo=${leapp_upgrade_repo:-"http://file.emea.redhat.com/~mreznik/tmp/leapp_upgrade_repositories.repo"}
dut=${dut:-"netqe05.knqe.eng.rdu2.dc.redhat.com"}
if [[ -z $arch ]]; then
	if [[ $dut == "netqe49.knqe.eng.rdu2.dc.redhat.com" ]]; then
		arch="aarch64"
		RPM_OVS=$(echo $RPM_OVS | sed 's/x86_64/aarch64/g')
		image_name="rhel9.4.aarch64.64k.qcow2"
	else
		arch="x86_64"
	fi
fi
ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"
NIC_NUM=2

if [[ $(echo $COMPOSE | awk -F - '{print $2}' | awk -F '.' '{print $1}') -lt 10 ]]; then
	locate_pkg=mlocate
else
	locate_pkg=plocate
fi

arch_test=${arch_test:-"x86_64"}
RPM_OVS_AARCH64=${RPM_OVS_AARCH64:-$(echo $RPM_OVS | sed 's/x86_64/aarch64/g')}
RPM_OVS_TCPDUMP_PYTHON_AARCH64=${RPM_OVS_TCPDUMP_PYTHON_AARCH64:-$(echo $RPM_OVS_TCPDUMP_PYTHON | sed 's/x86_64/aarch64/g')}

if [[ "$arch_test" == "x86_64" ]]; then
	dut="netqe05.knqe.eng.rdu2.dc.redhat.com"
	NIC_DRIVER="ice"
elif [[ "$arch_test" == "aarch64" ]]; then
	dut="netqe49.knqe.eng.rdu2.dc.redhat.com"
	NIC_DRIVER="mlx5_core"
	RPM_OVS=$RPM_OVS_AARCH64
	ovs_rpm_name=$(echo $RPM_OVS_AARCH64 | awk -F "/" '{print $NF}')
fi

RHEL_VER_MAJOR=$(echo $COMPOSE | awk -F "-" '{print $2}' | awk -F "." '{print $1}')
RPM_LIST=$(grep -w $(basename $RPM_OVS | awk -F "-" '{print $1}') ~/fdp_package_list.sh | grep RHEL$RHEL_VER_MAJOR | egrep -vi 'python|tcpdump|selinux')

LATEST_RPM_OVS=$(echo $RPM_LIST | awk '{print $NF}' | awk -F "=" '{print $NF}')
RPM_OVS_VER=$(basename $RPM_OVS | awk -F ".el" '{print $1}' | awk -F "-" '{print $NF}')
LATEST_RPM_OVS_VER=$(basename $LATEST_RPM_OVS | awk -F ".el" '{print $1}' | awk -F "-" '{print $NF}')

if [[ -z $STARTING_RPM_OVS ]]; then
	if [[ $(basename $LATEST_RPM_OVS) == $RPM_OVS ]]; then
		STARTING_RPM_OVS=$(echo $RPM_LIST | awk {'print $(NF-1)}' | awk -F "=" '{print $NF}')
	elif [[ $LATEST_RPM_OVS_VER -lt $RPM_OVS_VER ]]; then
		STARTING_RPM_OVS=$LATEST_RPM_OVS
	fi
fi

STARTING_STREAM=$(grep $STARTING_RPM_OVS ~/fdp_package_list.sh | awk -F "_" '{print $2}')

if [[ -z $STARTING_RPM_OVS_SELINUX_EXTRA_POLICY ]]; then
	STARTING_RPM_OVS_SELINUX_EXTRA_POLICY=$(grep $STARTING_STREAM ~/fdp_package_list.sh | grep -i selinux | grep RHEL$RHEL_VER_MAJOR | awk -F "=" '{print $NF}')
fi

if [[ -z $OVS_LATEST_STREAM_PKG ]]; then
	OVS_LATEST_STREAM_PKG=$(grep OVS ~/fdp_package_list.sh | grep RHEL$RHEL_VER_MAJOR | egrep -vi 'python|tcpdump|selinux' | tail -n1 | awk -F "=" '{print $NF}')
fi

FDP_STREAM=$(basename $RPM_OVS | awk -F "-" '{print $1}' | sed s/openvswitch//g )

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/ovs_upgrade | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE  --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --arch=x86_64 --machine=$dut --topo=singleHost --systype=machine --param=dbg_flag="$dbg_flag" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=LEAPP_UPGRADE=no --wb "($dut), $COMPOSE, openvswitch/ovs_upgrade, LEAPP UPGRADE: no  \`ovs_upgrade Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest ~/git/my_fork/kernel/networking/openvswitch/ovs_upgrade | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE  --kernel-options "crashkernel=640M" --arch=x86_64 --machine=$dut --topo=singleHost --systype=machine --param=dbg_flag="$dbg_flag" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=LEAPP_UPGRADE=no --wb "($dut), $COMPOSE, openvswitch/ovs_upgrade, LEAPP UPGRADE: no  \`ovs_upgrade Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/ovs_upgrade | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE  --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --arch=aarch64 --machine=$dut --topo=singleHost --systype=machine --param=dbg_flag="$dbg_flag" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5"--param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=LEAPP_UPGRADE=no --wb "($dut), $COMPOSE, openvswitch/ovs_upgrade, LEAPP UPGRADE: no  \`ovs_upgrade Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest ~/git/my_fork/kernel/networking/openvswitch/ovs_upgrade | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE  --kernel-options "crashkernel=640M" --arch=aarch64 --machine=$dut --topo=singleHost --systype=machine --param=dbg_flag="$dbg_flag" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=LEAPP_UPGRADE=no --wb "($dut), $COMPOSE, openvswitch/ovs_upgrade, LEAPP UPGRADE: no  \`ovs_upgrade Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
fi

rm -f *.xml	
popd 2>/dev/null
