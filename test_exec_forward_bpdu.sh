#!/bin/bash

# forward_bpdu

echo "COMPOSE is: $COMPOSE"

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
pushd ~ &>/dev/null
fdp_release=$FDP_RELEASE
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
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
	server="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
	client="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
	server_driver="i40e"
	client_driver="sfc"
elif [[ "$arch_test" == "aarch64" ]]; then
	server="netqe49.knqe.eng.rdu2.dc.redhat.com"
	client="netqe24.knqe.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	ovs_rpm_name=$(echo $RPM_OVS_AARCH64 | awk -F "/" '{print $NF}')
fi

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest $KERNEL_TESTS_HOME/kernel/networking/openvswitch/of_rules | runtest --task-fetch-url /distribution/check-install@ --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --ks-pre "systemctl stop NetworkManager-wait-online.service" --ks-post "systemctl disable NetworkManager-wait-online.service" --ks-append="rootpw redhat" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M rd.net.timeout.dhcp=30 rd.net.timeout.carrier=10 systemd.default_timeout_start_sec=5s systemd.default_timeout_stop_sec=5s" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$server,$client --systype=machine,machine --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="3c:fd:fe:ad:86:b4 3c:fd:fe:ad:86:b5","00:0f:53:7c:b2:70 00:0f:53:7c:b2:71" --param=mh-NIC_DRIVER=$server_driver,$client_driver --param=NIC_NUM=2 --param=image_name=$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --nrestraint --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/forward_bpdu, Client driver: $client_driver, Server driver: $server_driver  $special_info \`forward_bpdu Image Mode\`" --insert-task="/kernel/networking/openvswitch/common/misc_tasks/fix_nm_wait_online {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/fix_nm_wait_online {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest $KERNEL_TESTS_HOME/kernel/networking/openvswitch/of_rules | runtest --task-fetch-url /distribution/check-install@ --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --ks-pre "systemctl stop NetworkManager-wait-online.service" --ks-post "systemctl disable NetworkManager-wait-online.service" --ks-append="rootpw redhat" --kernel-options "crashkernel=640M rd.net.timeout.dhcp=30 rd.net.timeout.carrier=10 systemd.default_timeout_start_sec=5s systemd.default_timeout_stop_sec=5s" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$server,$client --systype=machine,machine --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="3c:fd:fe:ad:86:b4 3c:fd:fe:ad:86:b5","00:0f:53:7c:b2:70 00:0f:53:7c:b2:71" --param=mh-NIC_DRIVER=$server_driver,$client_driver --param=NIC_NUM=2 --param=image_name=$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/forward_bpdu, Client driver: $client_driver, Server driver: $server_driver  $special_info \`forward_bpdu Package Mode\`" --insert-task="/kernel/networking/openvswitch/common/misc_tasks/fix_nm_wait_online {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/fix_nm_wait_online {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest $KERNEL_TESTS_HOME/kernel/networking/openvswitch/of_rules | runtest -B "64k" --task-fetch-url /distribution/check-install@ --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --ks-append="rootpw redhat" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --arch="x86_64,aarch64" --machine=$server,$client --systype=machine,machine --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5","0c:42:a1:22:a3:46 0c:42:a1:22:a3:47" --param=mh-NIC_DRIVER=$server_driver,$client_driver --param=NIC_NUM=2 --param=mh-image_name=$VM_IMAGE_AARCH64,$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=mh-RPM_OVS=$RPM_OVS_AARCH64,$RPM_OVS --nrestraint --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/forward_bpdu, Client driver: $client_driver, Server driver: $server_driver  $special_info \`ARM Testing, forward_bpdu Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest $KERNEL_TESTS_HOME/kernel/networking/openvswitch/of_rules | runtest -B "64k" --task-fetch-url /distribution/check-install@ --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --ks-append="rootpw redhat" --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --arch="x86_64,aarch64" --machine=$server,$client --systype=machine,machine --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5","0c:42:a1:22:a3:46 0c:42:a1:22:a3:47" --param=mh-NIC_DRIVER=$server_driver,$client_driver --param=NIC_NUM=2 --param=mh-image_name=$VM_IMAGE_AARCH64,$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=mh-RPM_OVS=$RPM_OVS_AARCH64,$RPM_OVS --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/forward_bpdu, Client driver: $client_driver, Server driver: $server_driver  $special_info \`ARM Testing, forward_bpdu Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
fi

popd &>/dev/null
