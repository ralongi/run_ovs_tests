#!/bin/bash

# mcast_snoop

echo "COMPOSE is: $COMPOSE"

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
pushd ~/temp
fdp_release=$FDP_RELEASE
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
#server="netqe51.knqe.eng.rdu2.dc.redhat.com"
#client="netqe52.knqe.eng.rdu2.dc.redhat.com"
#server_driver="ice"
#client_driver="i40e"
ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')	
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"

if [[ $(echo $COMPOSE | awk -F - '{print $2}' | awk -F '.' '{print $1}') -lt 10 ]]; then
	locate_pkg=mlocate
else
	locate_pkg=plocate
fi

arch_test=${arch_test:-"x86_64"}
RPM_OVS_AARCH64=${RPM_OVS_AARCH64:-$(echo $RPM_OVS | sed 's/x86_64/aarch64/g')}
RPM_OVS_TCPDUMP_PYTHON_AARCH64=${RPM_OVS_TCPDUMP_PYTHON_AARCH64:-$(echo $RPM_OVS_TCPDUMP_PYTHON | sed 's/x86_64/aarch64/g')}

if [[ "$arch_test" == "x86_64" ]]; then
	server="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
	client="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
	server_driver="sfc"
	client_driver="i40e"
elif [[ "$arch_test" == "aarch64" ]]; then
	server="netqe24.knqe.eng.rdu2.dc.redhat.com"
	client="netqe49.knqe.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	ovs_rpm_name=$(echo $RPM_OVS_AARCH64 | awk -F "/" '{print $NF}')
fi
#SERVER_NIC_MAC_STRING="10:70:fd:5d:76:ac 10:70:fd:5d:76:ad"
#CLIENT_NIC_MAC_STRING="3c:fd:fe:ea:f8:10 3c:fd:fe:ea:f8:11"

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/mcast_snoop" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70 00:0f:53:7c:b2:71","3c:fd:fe:ad:86:b4 3c:fd:fe:ad:86:b5" --param=image_name=$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/mcast_snoop, Client driver: $client_driver, Server driver: $server_driver  $special_info \`mcast_snoop Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	else
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/mcast_snoop" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64" --ks-append="rootpw redhat" --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70 00:0f:53:7c:b2:71","3c:fd:fe:ad:86:b4 3c:fd:fe:ad:86:b5" --param=image_name=$VM_IMAGE --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/mcast_snoop, Client driver: $client_driver, Server driver: $server_driver  $special_info \`mcast_snoop Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/mcast_snoop" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64,aarch64" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="0c:42:a1:22:a3:46 0c:42:a1:22:a3:47","94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=mh-RPM_OVS=$RPM_OVS,$RPM_OVS_AARCH64 --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/mcast_snoop, Client driver: $client_driver, Server driver: $server_driver  $special_info \`mcast_snoop Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	else
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/mcast_snoop" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64,aarch64" --ks-append="rootpw redhat" --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="0c:42:a1:22:a3:46 0c:42:a1:22:a3:47","94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=mh-RPM_OVS=$RPM_OVS,$RPM_OVS_AARCH64 --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/mcast_snoop, Client driver: $client_driver, Server driver: $server_driver  $special_info \`mcast_snoop Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	fi
fi	

rm -f ~/git/my_fork/kernel/networking/tools/runtest-network/job*.xml --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
popd 2>/dev/null
