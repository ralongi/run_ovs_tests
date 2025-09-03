#!/bin/bash

# memory_leak_soak

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
pushd ~/git/my_fork/kernel/networking/openvswitch/memory_leak_soak
fdp_release_dir=$(echo $FDP_RELEASE | tr -d [" ".])
#SERVERS=$dut
#CLIENTS="null"
ROLE="STANDALONE"
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
NIC_DRIVER=${NIC_DRIVER:-"i40e"}
OVS_TOPO=${OVS_TOPO:-""}
ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')
skip_dpdk_tests=${skip_dpdk_tests:-"yes"}
skip_kernel_tests=${skip_kernel_tests:-"no"}
compose_minor_ver=$(echo $COMPOSE | awk -F "-" '{print $2}' | awk -F "." '{print $1"."$2}')
image_name=${image_name:-"rhel"$compose_minor_ver".qcow2"}
gen_valgrind_suppressions=${gen_valgrind_suppressions:-"yes"}
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
	dut=${dut:-"wsfd-advnetlab34.anl.eng.rdu2.dc.redhat.com"}
	NIC_DRIVER="i40e"
elif [[ "$arch_test" == "aarch64" ]]; then
	dut="netqe49.knqe.eng.rdu2.dc.redhat.com"
	NIC_DRIVER="mlx5_core"
	RPM_OVS=$RPM_OVS_AARCH64
	ovs_rpm_name=$(echo $RPM_OVS_AARCH64 | awk -F "/" '{print $NF}')
fi

if [[ "$dut" == "wsfd-advnetlab34.anl.eng.rdu2.dc.redhat.com" ]]; then
	NIC_MAC_STRING="e4:43:4b:a8:20:aa e4:43:4b:a8:20:ac"
elif [[ "$dut" == "wsfd-advnetlab33.anl.eng.rdu2.dc.redhat.com" ]]; then
	NIC_MAC_STRING="e4:43:4b:a8:18:44 e4:43:4b:a8:18:46"
elif [[ "$dut" == "netqe49.knqe.eng.rdu2.dc.redhat.com" ]]; then
	NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5"
fi

echo "DUT: $dut"
echo "let's go!"

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ "$dut" == "wsfd-advnetlab34.anl.eng.rdu2.dc.redhat.com" ]]; then
		if [[ $image_mode == "yes" ]]; then
			# Full test
			lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="e4:43:4b:a8:20:aa e4:43:4b:a8:20:ac" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
		else
			lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="e4:43:4b:a8:20:aa e4:43:4b:a8:20:ac" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
		fi
	elif [[ "$dut" == "wsfd-advnetlab33.anl.eng.rdu2.dc.redhat.com" ]]; then
		if [[ $image_mode == "yes" ]]; then
			# Full test
			lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="e4:43:4b:a8:18:44 e4:43:4b:a8:18:46" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
		else
			lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="e4:43:4b:a8:18:44 e4:43:4b:a8:18:46" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
		fi	
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		# Full test
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Image Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	else
		lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info \`memory_leak_soak Package Mode\`" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	fi
fi

popd 2>/dev/null


			# All tests, short duration
			#lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING=$NIC_MAC_STRING --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=traffic_runtime=1000 --param=mem_check_interval=30s --param=num_mem_checks=24 --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"

			# 1K flow tests only, short duration (sanity check)
			#lstest | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --product=$product --retention-tag=$retention_tag --machine=$dut --systype=machine --param=ROLE=$ROLE --param=dbg_flag="set -x" --param=skip_kernel_tests=$skip_kernel_tests --param=skip_dpdk_tests=$skip_dpdk_tests --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=image_name=$image_name --param=SELINUX=$SELINUX --param=OVS_TOPO=$OVS_TOPO --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING=$NIC_MAC_STRING --param=NIC_DRIVER=$NIC_DRIVER --param=NIC_NUM=2 --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=RPM_OVN_COMMON=$RPM_OVN_COMMON --param=RPM_OVN_CENTRAL=$RPM_OVN_CENTRAL --param=RPM_OVN_HOST=$RPM_OVN_HOST --param=traffic_runtime=1000 --param=mem_check_interval=30s --param=num_mem_checks=24 --param=skip_5k_flows=yes --param=skip_10k_flows=yes --param=skip_25k_flows=yes --param=skip_100k_flows=yes --param=skip_1m_flows=yes --param=fdp_release_dir=$fdp_release_dir --param=trex_server=$trex_server --param=gen_valgrind_suppressions=$gen_valgrind_suppressions --wb "DUT: $dut, FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/memory_leak_soak, Driver: $NIC_DRIVER $special_info" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
