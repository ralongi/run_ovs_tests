#!/bin/bash

# power_cycle_crash

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
dut=${dut:-"netqe05.knqe.eng.rdu2.dc.redhat.com"}
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"
if [[ -z $arch ]]; then
	if [[ $dut == "netqe49.knqe.eng.rdu2.dc.redhat.com" ]]; then
		arch="aarch64"
		RPM_OVS=$(echo $RPM_OVS | sed 's/x86_64/aarch64/g')
		image_name="rhel9.4.aarch64.64k.qcow2"
	else
		arch="x86_64"
	fi
fi

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
COMPOSE_VER_MINOR=$(echo $COMPOSE | awk -F "-" '{print $2}' | sed s/.0//g)
if [[ -z $image_name ]]; then
	image_name="rhel$COMPOSE_VER_MINOR.qcow2"
fi
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"
NIC_NUM=2

pushd ~/temp

#--watchdog-panic <arg>     set <watchdog panic="{reboot|ignore|None}"/>
# --watchdog-panic "set watchdog panic=ignore"

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/power_cycle_crash/set_config | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --watchdog-panic "ignore" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --ks-post "$(cat ~/temp/rhts_power.sh)" --arch=x86_64 --machine=$dut --topo=singleHost --systype=machine $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=FDP_STREAM=$FDP_STREAM --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --wb "(Standalone: $dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/power_cycle_crash $brew_build $special_info \`power_cycle_crash Image Mode\`" --append-task="/distribution/utils/power-cycle" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/crash_sysrq_c {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest ~/git/my_fork/kernel/networking/openvswitch/power_cycle_crash/set_config | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --watchdog-panic "ignore" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --ks-post "$(cat ~/temp/rhts_power.sh)" --arch=x86_64 --machine=$dut --topo=singleHost --systype=machine $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=FDP_STREAM=$FDP_STREAM --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="b4:96:91:a5:b9:48 b4:96:91:a5:b9:49" --param=NIC_DRIVER=$NIC_DRIVER --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --wb "(Standalone: $dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/power_cycle_crash $brew_build $special_info \`power_cycle_crash Package Mode\`" --append-task="/distribution/utils/power-cycle" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/crash_sysrq_c {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		lstest ~/git/my_fork/kernel/networking/openvswitch/power_cycle_crash/set_config | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --watchdog-panic "ignore" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --ks-post "$(cat ~/temp/rhts_power.sh)" --arch=aarch64 --machine=$dut --topo=singleHost --systype=machine $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE_AARCH64 --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=FDP_STREAM=$FDP_STREAM --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --wb "(Standalone: $dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/power_cycle_crash $brew_build $special_info \`power_cycle_crash Image Mode\`" --append-task="/distribution/utils/power-cycle" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/crash_sysrq_c {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	else
		lstest ~/git/my_fork/kernel/networking/openvswitch/power_cycle_crash/set_config | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --kernel-options "crashkernel=640M" --watchdog-panic "ignore" --ks-append="rootpw redhat" --product=$product --retention-tag=$retention_tag --ks-post "$(cat ~/temp/rhts_power.sh)" --arch=aarch64 --machine=$dut --topo=singleHost --systype=machine $(echo "$zstream_repo_list") $(echo "$brew_build_cmd") --param=ROLE="STANDALONE" --param=image_name=$VM_IMAGE_AARCH64 --param=dbg_flag="$dbg_flag" --param=SELINUX=$SELINUX --param=FDP_STREAM=$FDP_STREAM --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=NIC_MAC_STRING="94:6d:ae:d9:23:f4 94:6d:ae:d9:23:f5" --param=NIC_DRIVER=$NIC_DRIVER --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --wb "(Standalone: $dut), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/power_cycle_crash $brew_build $special_info \`power_cycle_crash Package Mode\`" --append-task="/distribution/utils/power-cycle" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task="/kernel/networking/openvswitch/common/misc_tasks/crash_sysrq_c {dbg_flag=set -x}" --append-task="/kernel/networking/openvswitch/power_cycle_crash/check_config {dbg_flag=set -x} {ROLE=STANDALONE}" --append-task=/kernel/networking/openvswitch/common/misc_tasks/recover_pxe_boot
	fi
fi

popd 2>/dev/null
