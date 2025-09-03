#!/bin/bash

# sanity_check

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
pushd ~/git/my_fork/kernel/networking/openvswitch/sanity_check
fdp_release_dir=$(echo $FDP_RELEASE | tr -d [" ".])
dut=${dut:-"netqe05.knqe.eng.rdu2.dc.redhat.com"}

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

ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')
NIC_DRIVER=${NIC_DRIVER:-"i40e"}
#netscout_pair1=${netscout_pair1:-"NETQE32_P3P1 XENA_M5P0"}
#netscout_pair2=${netscout_pair2:-"NETQE32_P3P2 XENA_M5P1"}
skip_traffic_tests=${skip_traffic_tests:-"yes"}
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
COMPOSE_VER_MINOR=$(echo $COMPOSE | awk -F "-" '{print $2}' | sed s/.0//g)
if [[ -z $image_name ]]; then
	image_name="rhel$COMPOSE_VER_MINOR.qcow2"
fi
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"
NIC_NUM=2
ovs_restart_threshold=${ovs_restart_threshold:-"6"}

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$dut --topo=singlehost $(echo "$repo_cmd") $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") -param=dbg_flag="set -x" --param=xena_chassis_module=5 --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=image_name=$image_name --param=ovs_restart_threshold=$ovs_restart_threshold --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=skip_traffic_tests=$skip_traffic_tests --param=skip_cleanup_env=yes --param=skip_openvswitch_restart_test=no --param=fdp_release_dir=$fdp_release_dir --wb "($dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/sanity_check, Driver: $NIC_DRIVER $brew_build $special_info \`sanity_check Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}"
	else
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch=x86_64 --machine=$dut --topo=singlehost $(echo "$repo_cmd") $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") -param=dbg_flag="set -x" --param=xena_chassis_module=5 --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE --param=ovs_restart_threshold=$ovs_restart_threshold --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=skip_traffic_tests=$skip_traffic_tests --param=skip_cleanup_env=yes --param=skip_openvswitch_restart_test=no --param=fdp_release_dir=$fdp_release_dir --wb "($dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/sanity_check, Driver: $NIC_DRIVER $brew_build $special_info \`sanity_check Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}"
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch="aarch64" --machine=$dut --topo=singlehost $(echo "$repo_cmd") $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") -param=dbg_flag="set -x" --param=xena_chassis_module=5 --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE_AARCH64 --param=ovs_restart_threshold=$ovs_restart_threshold --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS_AARCH64 --param=skip_traffic_tests=$skip_traffic_tests --param=skip_cleanup_env=yes --param=skip_openvswitch_restart_test=no --param=fdp_release_dir=$fdp_release_dir --wb "($dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/sanity_check, Driver: $NIC_DRIVER $brew_build $special_info \`sanity_check Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}"
	else
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --arch="aarch64" --machine=$dut --topo=singlehost $(echo "$repo_cmd") $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") -param=dbg_flag="set -x" --param=xena_chassis_module=5 --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=ROLE="STANDALONE" --param=image_name=$image_name --param=ovs_restart_threshold=$ovs_restart_threshold --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS_AARCH64 --param=skip_traffic_tests=$skip_traffic_tests --param=skip_cleanup_env=yes --param=skip_openvswitch_restart_test=no --param=fdp_release_dir=$fdp_release_dir --wb "($dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/sanity_check, Driver: $NIC_DRIVER $brew_build $special_info \`sanity_check Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}"
	fi
fi
	
popd 2>/dev/null
