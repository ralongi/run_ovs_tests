#!/bin/bash

# vm100

echo "COMPOSE is: $COMPOSE"

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
pushd ~/temp
fdp_release=$FDP_RELEASE
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')	
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"
total_guests=${total_guests:-"300"}
tunnel_type=${tunnel_type:-"ipv4_geneve"}

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

pushd ~

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/vm100 | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70","3c:fd:fe:ad:86:b4" --param=rpm_ovs_selinux=$RPM_OVS_SELINUX_EXTRA_POLICY --param=rpm_ovs=$RPM_OVS --param=image_name=$VM_IMAGE --param=total_guests=$total_guests --param=tunnel_type=$tunnel_type --wb "(Server: $SERVERS, Client: $CLIENTS), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/vm100 $brew_build $special_info \`vm100 Image Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}"--append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"	
	elif [[ $image_mode == "no" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/vm100 | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70","3c:fd:fe:ad:86:b4" --param=rpm_ovs_selinux=$RPM_OVS_SELINUX_EXTRA_POLICY --param=rpm_ovs=$RPM_OVS --param=image_name=$VM_IMAGE --param=total_guests=$total_guests --param=tunnel_type=$tunnel_type --wb "(Server: $SERVERS, Client: $CLIENTS), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/vm100 $brew_build $special_info \`vm100 Package Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"	
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/vm100 | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch="x86_64,aarch64" --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70","3c:fd:fe:ad:86:b4" --param=rpm_ovs_selinux=$RPM_OVS_SELINUX_EXTRA_POLICY --param=rpm_ovs=$RPM_OVS --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=total_guests=$total_guests --param=tunnel_type=$tunnel_type --wb "(Server: $SERVERS, Client: $CLIENTS), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/vm100 $brew_build $special_info \`vm100 Image Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"	
	elif [[ $image_mode == "no" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/vm100 | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch="x86_64,aarch64" --machine=$server,$client $(echo "$brew_build_cmd") --systype=machine,machine $(echo "$zstream_repo_list") --param=dbg_flag="$dbg_flag" --param=SERVERS="$server" --param=CLIENTS="$client" --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="00:0f:53:7c:b2:70","3c:fd:fe:ad:86:b4" --param=rpm_ovs_selinux=$RPM_OVS_SELINUX_EXTRA_POLICY --param=rpm_ovs=$RPM_OVS --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=total_guests=$total_guests --param=tunnel_type=$tunnel_type --wb "(Server: $SERVERS, Client: $CLIENTS), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/vm100 $brew_build $special_info \`vm100 Package Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"	
	fi
fi

popd 2>/dev/null
