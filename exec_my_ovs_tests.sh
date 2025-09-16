#!/bin/bash

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
#RHEL_VER=${RHEL_VER:-""}
RHEL_VER_MAJOR=$(echo $RHEL_VER | awk -F "." '{print $1}')
SELINUX=${SELINUX:-"yes"}
COMPOSE=${COMPOSE:-""}
GUEST_IMG_VALUE=$RHEL_VER
/home/ralongi/gvar/bin/gvar $COMPOSE
repo=${repo:-""}
if [[ $repo ]]; then
	repo_cmd="--repo=$repo"
fi
brew_target_flag=${brew_target_flag:-"off"}

if [[ $brew_build ]]; then export brew_build_cmd="-B $brew_build"; fi

# Attempt to set uefi systems to PXE boot
# List of target uefi systems in file ~/uefi_pssh_hosts.txt, run ~/set_uefi_bootnext_pxi.sh on target systems
#echo "Attempting to set PXE boot on uefi systems before running tests..."
#num_pssh_hosts=$(cat ~/uefi_pssh_hosts.txt | wc -l)
#timeout 10s bash -c "until pssh -O StrictHostKeyChecking=no -p $num_pssh_hosts -h ~/uefi_pssh_hosts.txt -t 0 -l root 'bash -s' < ~/set_uefi_bootnext_pxi.sh; do sleep 0; done"

# Script to execute all of my ovs tests

source ~/fdp_package_list.sh > /dev/null

. ~/get_zstream_compose_function.sh

use_hpe_synergy=${use_hpe_synergy:-"no"}

sedeasy ()
{
sed -i "s/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3
}

get_beaker_compose_id()
{
    dbg_flag=${dbg_flag:-"set +x"}
    $dbg_flag

    rhel_minor_ver=$1
    rhel_major_ver=$(echo $rhel_minor_ver | awk -F "." '{print $1}')
    #if [[ $(echo $rhel_minor_ver | awk -F "." '{print $1}') == "8" ]]; then
    #	rhel_minor_ver=$rhel_minor_ver".0"
    #fi

    source ~/.bash_profile
    gvar -v > /dev/null
    if [[ $? -ne 0 ]]; then
	    pushd ~
	    git clone git@github.com:arturoherrero/gvar.git
	    echo 'export PATH="${PATH}:~/gvar/bin"' >> ~/.bash_profile
	    source ~/.bash_profile
	    popd 2>/dev/null
    fi
	    
    display_usage()
    {
	    echo "This script will report the latest stable compose available for the RHEL version provided."
	    echo "Usage: $0 <target RHEL version>"
	    echo "Example: $0 8.1"
	    exit 0
    }

    if [[ $# -lt 1 ]] || [[ $1 = "-h" ]] || [[ $1 = "--help" ]]	|| [[ $1 = "-?" ]]; then
	    display_usage
    fi

    view_id=$(curl -sL https://beaker.engineering.redhat.com/distrotrees/?simplesearch=rhel-$rhel_minor_ver | grep '/distros/view' | grep -v '\.n' | egrep -v '\.n|\.d' | head -n1 | awk -F ">" '{print $1}' | awk -F "=" '{print $NF}' | tr -d '"')
    distro_id=$(curl -sL https://beaker.engineering.redhat.com/distros/view?id="$view_id" | grep distro_tree_id | head -n1 | awk -F "=" '{print $3}' | awk '{print $1}' | tr -d '"')
    #distro_id=$(curl -sL https://beaker.engineering.redhat.com/distros/view?id="$view_id" | grep -A7 distrotrees | grep -A3 $arch | grep distro_tree_id | sed 's/[^0-9]*//g')
    export latest_compose_id=$(curl -sL https://beaker.engineering.redhat.com/distrotrees/?simplesearch=rhel-$rhel_minor_ver | grep '/distros/view' | egrep -v '\.n|\.d' | grep -v '\.d' | head -n1 | awk -F ">" '{print $2}' | awk -F "<" '{print $1}')
    build_url=$(curl -sL https://beaker.engineering.redhat.com/distrotrees/$distro_id#lab-controllers | grep http | grep bos.redhat.com | grep -v href | awk '{print $NF}')
    arch=$(echo $build_url | awk -F "/os" '{print $1}' | awk -F "/" '{print $NF}')
    #el_ver=$(echo "el$rhel_major_ver")
    kernel_id=$(curl -sL "$build_url"Packages | egrep -w kernel | head -n1 | awk -F ">" '{print $6}' | awk -F '"' '{print $2}')
    echo $kernel_id > ~/kernel_id.tmp
    kernel_id=$(sed "s/.$arch.rpm//g" ~/kernel_id.tmp)
    rm -f ~/kernel_id.tmp
    echo ""
    echo "The latest stable RHEL $rhel_minor_ver compose available in beaker is: $latest_compose_id"
    echo "The kernel associated with compose $latest_compose_id is: $kernel_id"
    echo ""
    gvar latest_compose_id=$latest_compose_id
}

netscout_cable()
{
	rhel_version=$(cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g')
	local port1=$(echo $1 | tr '[:lower:]' '[:upper:]')
	local port2=$(echo $2 | tr '[:lower:]' '[:upper:]')
	# possible netscout switches: bos_3200  bos_3903  nay_3200  nay_3901
	# set this in runtest.sh as necessary --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	netscout_switch=${netscout_switch:-"bos_3903"}
	
	if [[ "$rhel_version" -eq 8 ]]; then
		pushd /home/NetScout/
		rm -f settings.cfg
		wget -O ./settings.cfg http://netqe-infra01.knqe.eng.rdu2.dc.redhat.com/NSConn/"$netscout_switch".cfg
		sleep 2
		python3 /home/ralongi/github/NetScout/NSConnect.py --connect $port1 $port2
		popd 2>/dev/null
	elif [[ "$rhel_version" -eq 7 ]]; then	
		scl enable rh-python34 - << EOF
			pushd /home/NetScout/
			rm -f settings.cfg
			wget -O ./settings.cfg http://netqe-infra01.knqe.eng.rdu2.dc.redhat.com/NSConn/"$netscout_switch".cfg
			sleep 2
			python /home/ralongi/github/NetScout/NSConnect.py --connect $port1 $port2
			popd 2>/dev/null
EOF
	fi
}

# Get the latest driverctl package URLs

get_latest_driverctl()
{
    $dbg_flag
    download_server="download.devel.redhat.com"
    timeout 5s bash -c "curl -sL http://$download_server/brewroot/packages/driverctl"
    if [[ $? -ne 0 ]]; then
    	download_server="download.eng.bos.redhat.com"
    	timeout 5s bash -c "curl -sL http://$download_server/brewroot/packages/driverctl"
		if [[ $? -ne 0 ]]; then
			echo "The driverctl package download servers are unreachable"
			return 1
		fi
	fi    
    
	latest_build_id=$(curl -sL http://$download_server/brewroot/packages/driverctl | grep valign | tail -n1 | awk -F '"' '{print $8}' | tr -d '/')
	
	if [[ ! $(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/ | grep el8) ]]; then
	    latest_build_id=$(curl -sL http://$download_server/brewroot/packages/driverctl | grep valign | tail -n2 | head -n1 | awk -F '"' '{print $8}' | tr -d '/')
	fi
	
	latest_el8_package_id=$(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/ | grep el8 | head -n1 |  awk -F '"' '{print $8}' | tr -d '/')
	el8_rpm=$(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el8_package_id/noarch/ | grep rpm | awk -F '"' '{print $8}')
	
	echo "RHEL-8 URL: http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el8_package_id/noarch/$el8_rpm"	
	export DRIVERCTL_RHEL8="http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el8_package_id/noarch/$el8_rpm"
	
	if [[ ! $(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/ | grep el9) ]]; then
	    latest_build_id=$(curl -sL http://download.devel.redhat.com/brewroot/packages/driverctl | grep valign | tail -n2 | head -n1 | awk -F '"' '{print $8}' | tr -d '/')
	fi    

	latest_el9_package_id=$(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/ | grep el9 | head -n1 |  awk -F '"' '{print $8}' | tr -d '/')

	el9_rpm=$(curl -sL http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el9_package_id/noarch/ | grep rpm | awk -F '"' '{print $8}')	
	
	echo "RHEL-9 URL: http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el9_package_id/noarch/$el9_rpm"	
	export DRIVERCTL_RHEL9="http://$download_server/brewroot/packages/driverctl/$latest_build_id/$latest_el9_package_id/noarch/$el9_rpm"
}

get_latest_driverctl

if [[ -z $RPM_DRIVERCTL ]]; then
	export RPM_DRIVERCTL=$DRIVERCTL_RHEL9
fi
if [[ -z $RPM_OVS_TCPDUMP_PYTHON ]]; then
	export RPM_OVS_TCPDUMP_PYTHON=$OVS310_PYTHON_25D_RHEL9
fi
if [[ -z $RPM_OVS_TCPDUMP_TEST ]]; then
	export RPM_OVS_TCPDUMP_TEST=$OVS310_TCPDUMP_25D_RHEL9
fi

# RHEL composes

# if using a specific compose, first execute: export COMPOSE=<target compose id" in terminal window where you are executing the scripts to kick off tests
echo "Checking to see if a COMPOSE has been specified..."
if [[ -z $COMPOSE ]]; then
    echo "No compose has been specified yet.  Will try to find a valid $RHEL_VER Z stream compose."
	get_zstream_compose $RHEL_VER
	if [[ $zstream_compose ]]; then
	    export COMPOSE=$zstream_compose
	    export brew_target_flag="off"
	    echo "Using Z stream compose $zstream_compose..."
	else
	    echo "No valid $RHEL_VER Z stream compose was found.  Will now use the latest available $RHEL_VER compose."
	    #/home/ralongi/github/tools/scripts/get_beaker_compose_id.sh $RHEL_VER
	    get_beaker_compose_id $RHEL_VER
	    export COMPOSE=$(/home/ralongi/gvar/bin/gvar $latest_compose_id | awk -F "=" '{print $NF}')
	    export brew_target_flag="on"
	    echo "Will install the latest available brew kernel on top of the latest available compose."
	    export cmds_to_run="--cmd-and-reboot $(cat ~/temp/tt.txt)"
	fi
fi

if [[ $brew_target_flag == "off" ]]; then
	export brew_target=""
else
	export brew_target=${brew_target:-"lstk"}
fi

echo "Using compose: $COMPOSE"

get_zstream_repos()
{
	$dbg_flag
	arch=${arch:-"x86_64"}
	z_stream_base=$(echo $COMPOSE | awk -F '-' '{print $2}' | tr -d . | cut -c-2)
	z_stream_base=$(echo $z_stream_base)z
	pushd ~/temp
	alias rm='rm' 
	rm -f zstream_repos.txt
	wget -O ZConfig.yaml https://gitlab.cee.redhat.com/kernel-qe/core-kernel/kernel-general/-/raw/master/Sustaining/ZConfig.yaml
	if [[ $(grep -w "$z_stream_base" ZConfig.yaml) ]]; then
		 zstream_repos=$(grep -A35 -w "$z_stream_base" ZConfig.yaml | grep "$arch": | tr -d "'" | awk '{$1="";print $0}' | sed 's/^ //g')
	fi
	echo "Zstream repos: $zstream_repos"    
	for i in $zstream_repos; do echo "--repo=$i" >> zstream_repos.txt; done
	export zstream_repo_list=$(cat zstream_repos.txt)
	rm -f ZConfig.yaml
	alias rm='rm -i'
	popd 2>/dev/null
}

get_dpdk_packages()
{
	$dbg_flag
	target_rhel_version=$1
	tmp0=$(mktemp)

	if [[ $2 ]]; then arch=$2; else arch=x86_64; fi
	x_tmp=$(curl -su : --negotiate  https://errata.devel.redhat.com/package/show/dpdk | grep $target_rhel_version.0 | head -n1)
	errata=$(curl -su : --negotiate  https://errata.devel.redhat.com/package/show/dpdk | grep -B1 "$x_tmp"| head -n1 | awk -F '"' '{print $(NF-1)}' | sed 's/\/advisory\///g')
	curl -su : --negotiate https://errata.devel.redhat.com/api/v1/erratum/$errata/builds | jq > ~/builds.txt
	build_id=$(grep "id" ~/builds.txt | awk '{print $NF}' | tr -d ,)
	curl -su : --negotiate https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=$build_id > ~/builds2.txt
	export RPM_DPDK=$(grep $arch.rpm ~/builds2.txt | egrep -v 'devel|tools|debug' | awk -F '"' '{print $4}')
	export RPM_DPDK_TOOLS=$(grep $arch.rpm ~/builds2.txt | grep tools | awk -F '"' '{print $4}')
	echo "RPM_DPDK=$RPM_DPDK" | tee -a $tmp0
	echo "RPM_DPDK_TOOLS=$RPM_DPDK_TOOLS" | tee -a $tmp0
	source $tmp0
	if [[ -z $RPM_DPDK ]]; then
		echo "It appears that the $arch arch is not available for DPDK"
		exit 1
	else
		echo "RPM_DPDK: $RPM_DPDK"
		echo "RPM_DPDK_TOOLS: $RPM_DPDK_TOOLS"
	fi
	rm -f ~/builds.txt ~/builds2.txt
	rm -f $tmp0
}

# DPDK packages for RHEL-7
if [[ -z $RPM_DPDK ]] || [[ -z $RPM_DPDK_TOOLS ]]; then
	if [[ $(echo $version_id  | awk -F '.' '{print $1}') -eq 7 ]]; then
		export RPM_DPDK_RHEL7=http://$download_server/brewroot/packages/dpdk/18.11.8/1.el7_8/x86_64/dpdk-18.11.8-1.el7_8.x86_64.rpm
		export RPM_DPDK_TOOLS_RHEL7=http://$download_server/brewroot/packages/dpdk/18.11.8/1.el7_8/x86_64/dpdk-tools-18.11.8-1.el7_8.x86_64.rpm
	#else
	#	version_id=$(echo $COMPOSE | awk -F "-" '{print $2}' | sed s/.0//g)
	#	get_dpdk_packages $version_id
	fi
fi

# Comment out below since DPDK packages are now included with openvswitch
#if [[ -z $RPM_DPDK ]] || [[ -z $RPM_DPDK_TOOLS ]]; then
#	if [[ $(echo $COMPOSE | grep RHEL-8) ]]; then
#		export RPM_DPDK=https://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/dpdk/21.11/2.el8_6/x86_64/dpdk-21.11-2.el8_6.x86_64.rpm
#		export RPM_DPDK_TOOLS=https://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/dpdk/21.11/2.el8_6/x86_64/dpdk-tools-21.11-2.el8_6.x86_64.rpm
#	elif [[ $(echo $COMPOSE | grep RHEL-9) ]]; then
#		export RPM_DPDK=https://download.eng.bos.redhat.com/brewroot/vol/rhel-9/packages/dpdk/21.11/2.el9_0/x86_64/dpdk-21.11-2.el9_0.x86_64.rpm
#		export RPM_DPDK_TOOLS=https://download.eng.bos.redhat.com/brewroot/vol/rhel-9/packages/dpdk/21.11/2.el9_0/x86_64/dpdk-tools-21.11-2.el9_0.x86_64.rpm
#	fi
#fi

#get_zstream_repos

# Netperf package
export SRC_NETPERF="http://netqe-infra01.knqe.eng.rdu2.dc.redhat.com/share/tools/netperf-20210121.tar.bz2"

# VM image names
if [[ -z $VM_IMAGE ]]; then
	export VM_IMAGE="rhel9.7.qcow2"
else
	export VM_IMAGE=$VM_IMAGE
fi

if [[ -z $VM_IMAGE_AARCH64 ]]; then
	export VM_IMAGE_AARCH64="rhel9.7.aarch64.qcow2"
else
	export VM_IMAGE_AARCH64=$VM_IMAGE_AARCH64
fi

# OVS packages
if [[ -z $RPM_OVS ]]; then
	export RPM_OVS=$OVS310_25D_RHEL9
else
	export RPM_OVS=$RPM_OVS
fi

# OVN packages
# If there is no value assigned for OVN packages, take the latest available

if [[ -z $RPM_OVN_COMMON ]]; then
	export RPM_OVN_COMMON=$(grep -i $FDP_RELEASE  ~/fdp_package_list.sh | grep -i OVN_COMMON | grep -i RHEL$RHEL_VER_MAJOR | awk -F '=' '{print $NF}' | tail -n1)
fi

if [[ -z $RPM_OVN_CENTRAL ]]; then
	export RPM_OVN_CENTRAL=$(grep -i $FDP_RELEASE  ~/fdp_package_list.sh | grep -i OVN_CENTRAL | grep -i RHEL$RHEL_VER_MAJOR | awk -F '=' '{print $NF}' | tail -n1)
fi

if [[ -z $RPM_OVN_HOST ]]; then
	export RPM_OVN_HOST=$(grep -i $FDP_RELEASE  ~/fdp_package_list.sh | grep -i OVN_HOST | grep -i RHEL$RHEL_VER_MAJOR | awk -F '=' '{print $NF}' | tail -n1)
fi

# SELinux packages
if [[ -z $RPM_OVS_SELINUX_EXTRA_POLICY ]]; then
	export RPM_OVS_SELINUX_EXTRA_POLICY=$OVS_SELINUX_25D_RHEL9
else
	export RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY
fi

# For rpm_dpdk variable used by openvswitch/perf tests
#export rpm_dpdk=$RPM_DPDK
#export rpm_dpdk_tools=$RPM_DPDK_TOOLS

#http_code=$(curl --silent --head --write-out '%{http_code}' "$RPM_DPDK" | grep HTTP | awk '{print $2}')
#if [[ "$http_code" -ne 200 ]]; then echo "$RPM_DPDK is NOT a valid link. Exiting..."; exit 1; fi

#http_code=$(curl --silent --head --write-out '%{http_code}' "$RPM_DPDK_TOOLS" | grep HTTP | awk '{print $2}')
#if [[ "$http_code" -ne 200 ]]; then echo "$RPM_DPDK_TOOLS is NOT a valid link. Exiting..."; exit 1; fi

# QEMU packages
#export QEMU_KVM_RHEV_RHEL7=http://download.devel.redhat.com/brewroot/packages/qemu-kvm-rhev/2.12.0/48.el7_9.2/x86_64/qemu-kvm-rhev-2.12.0-48.el7_9.2.x86_64.rpm

# OVN packages
export RPM_OVN=$OVN310_25D_RHEL9 

export BONDING_TESTS="ovs_test_bond_active_backup ovs_test_bond_set_active_slave ovs_test_bond_lacp_active ovs_test_bond_lacp_passive ovs_test_bond_balance_slb ovs_test_bond_balance_tcp"

export BONDING_CONTAINER_VLAN_TESTS="ovs_test_bond_active_backup ovs_test_bond_set_active_slave ovs_test_bond_lacp_active ovs_test_bond_lacp_passive ovs_test_bond_balance_slb ovs_test_bond_balance_tcp ovs_test_container_vlan"

export BONDING_CPU_TESTS="ovs_test_bond_active_backup ovs_test_bond_set_active_slave ovs_test_bond_lacp_active ovs_test_bond_lacp_passive ovs_test_bond_balance_slb ovs_test_bond_balance_tcp ovs_test_ns_enable_nomlockall_CPUAffinity_test"

export GRE_IPV6_TESTS="ovs_test_gre_ipv6 ovs_test_gre1_ipv6 ovs_test_gre_flow_ipv6 ovs_test_vlan_gre_ipv6 ovs_test_vlan_gre1_ipv6 ovs_test_vm_gre_ipv6 ovs_test_vm_gre1_ipv6 ovs_test_vm_gre_flow_ipv6 ovs_test_vm_vlan_gre_ipv6 ovs_test_vm_vlan_gre1_ipv6"

# Insert $FDP release into exec_perf_ci.sh and exec_endurance.sh
sedeasy "25D" "$FDP_RELEASE" ~/github/tools/ovs_testing/exec_perf_ci.sh
sedeasy "25D" "$FDP_RELEASE" ~/github/tools/ovs_testing/exec_endurance.sh

#pushd /home/ralongi/Documents/ovs_testing
#pushd /home/ralongi/global_docs/ovs_testing
pushd /home/ralongi/github/tools/ovs_testing

#./exec_ovs_upgrade.sh
./exec_sanity_check.sh
#./exec_vm100.sh
#./exec_ovs_qos.sh
#./exec_mcast_snoop.sh
#./exec_power_cycle_crash.sh
#./exec_forward_bpdu.sh
#./exec_of_rules.sh

# To run just the ovs_test_ns_enable_nomlockall_CPUAffinity_test for topo, add "cpu" to the string of arguments
#./exec_topo.sh ixgbe ovs_env=kernel
##./exec_topo.sh ixgbe ovs_env=ovs-dpdk
#./exec_topo.sh i40e ovs_env=kernel
##./exec_topo.sh i40e ovs_env=ovs-dpdk
#./exec_topo.sh e810_ice ovs_env=kernel
##./exec_topo.sh e810_ice ovs_env=ovs-dpdk
#./exec_topo.sh e830_ice ovs_env=kernel
##./exec_topo.sh e830_ice ovs_env=ovs-dpdk
#./exec_topo.sh e825_ice ovs_env=kernel
##./exec_topo.sh e825_ice ovs_env=ovs-dpdk
#./exec_topo.sh e810_ice_bp ovs_env=kernel
##./exec_topo.sh e810_ice_bp ovs_env=ovs-dpdk
#./exec_topo.sh e823_ice_bp ovs_env=kernel
##./exec_topo.sh e823_ice_bp ovs_env=ovs-dpdk
#./exec_topo.sh e823_ice_sfp ovs_env=kernel
##./exec_topo.sh e823_ice_sfp ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core cx5 ovs_env=kernel
##./exec_topo.sh mlx5_core cx5 ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core cx6 dx ovs_env=kernel
##./exec_topo.sh mlx5_core cx6 dx ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core cx6 lx ovs_env=kernel
##./exec_topo.sh mlx5_core cx6 lx ovs_env=ovs-dpdk
#./exec_topo.sh arm ovs_env=kernel

#./exec_topo.sh mlx5_core_arm cx7 ovs_env=kernel

##./exec_topo.sh arm ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core cx7 ovs_env=kernel
##./exec_topo.sh mlx5_core cx7 ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core bf2 ovs_env=kernel
##./exec_topo.sh mlx5_core bf2 ovs_env=ovs-dpdk
#./exec_topo.sh sts ovs_env=kernel
##./exec_topo.sh sts ovs_env=ovs-dpdk
#./exec_topo.sh t4l ovs_env=kernel
##./exec_topo.sh t4l ovs_env=ovs-dpdk
#./exec_topo.sh empire ovs_env=kernel
##./exec_topo.sh empire ovs_env=ovs-dpdk
#./exec_topo.sh bmc57504 ovs_env=kernel
##./exec_topo.sh bmc57504 ovs_env=ovs-dpdk
#./exec_topo.sh 6820c ovs_env=kernel
##./exec_topo.sh 6820c ovs_env=ovs-dpdk
#./exec_topo.sh mlx5_core bf3 ovs_env=kernel
##./exec_topo.sh mlx5_core bf3 ovs_env=ovs-dpdk

#./exec_endurance.sh cx5
#./exec_perf_ci.sh cx5
#./exec_endurance.sh cx6dx
#./exec_perf_ci.sh cx6dx
#./exec_endurance.sh cx6lx
#./exec_perf_ci.sh cx6lx
#./exec_endurance.sh bf2
#./exec_perf_ci.sh bf2
#./exec_endurance.sh bf3
#./exec_perf_ci.sh bf3

#./exec_topo.sh enic ovs_env=kernel
##./exec_topo.sh enic ovs_env=ovs-dpdk
#./exec_topo.sh qede ovs_env=kernel
##./exec_topo.sh qede ovs_env=ovs-dpdk
#./exec_topo.sh bnxt_en ovs_env=kernel
##./exec_topo.sh bnxt_en ovs_env=ovs-dpdk
#./exec_topo.sh nfp ovs_env=kernel
##./exec_topo.sh nfp ovs_env=ovs-dpdk

#./exec_ovs_memory_leak_soak.sh
#./exec_ovn_memory_leak_soak.sh

#./exec_regression_bug.sh

# Conntrack firewall rules Jiying Qiu (not related to driver)
# openvswitch/conntrack2 and openvswitch/conntrack_dpdk
#./exec_conntrack2.sh
#./exec_conntrack_dpdk.sh

# Stateful traffic Xena (by speed)
# openvswitch/conntrack3/ct_kernel and openvswitch/conntrack3/ct_userspace
# Google sheet: https://docs.google.com/spreadsheets/d/1cPG1ovmrCo1RhAMGVfK9SgKIEtj7yocjYP_CDvLUfYY/edit?usp=sharing
#./exec_ct_kernel.sh
#./exec_ct_userspace.sh

# ovs-dpdk-conntrack
# Google sheet: https://docs.google.com/spreadsheets/d/17MKqKpCmVV93dhCawgD-xxAm3aQweV5yszb82A-L-Kk/edit?usp=sharing
# search for "disable emc" and then "enable emc" in taskout.log file
#./exec_ovs_dpdk_conntrack.sh

# ovs-kernel-conntrack
# Google sheet: https://docs.google.com/spreadsheets/d/1qku7ViuVgAwWXobQjekv1JxNvfQ4rgjCOBX0NTeda9o/edit?usp=sharing
# search for "disable emc" and then "enable emc" in taskout.log file
#./exec_ovs_kernel_conntrack.sh

# ovs-dpdk-latency
# Google sheet: https://docs.google.com/spreadsheets/d/11BqpCkXoUXTVH4s0uMGZ4ieBOZzUNjbYS9E-3CxYIpI/edit?usp=sharing
# search for "Flows:" in taskout.log file
#./exec_ovs_dpdk_latency.sh

# xena_conntrack/xena_dpdk
#./exec_xena_dpdk.sh

### may need to add vm_100

#echo "FDP_STREAM2 is now set to $FDP_STREAM2"
echo "COMPOSE is: $COMPOSE"
echo "FDP Release is: $FDP_RELEASE"
echo "FDP Stream is: $FDP_STREAM"
echo "RPM_OVS: $RPM_OVS"
echo "RPM_OVN_CENTRAL: $RPM_OVN_CENTRAL"
echo "RPM_OVN_HOST: $RPM_OVN_HOST"
echo "RPM_OVN_COMMON: $RPM_OVN_COMMON"
echo "RPM_OVN_CENTRAL: $RPM_OVN_CENTRAL"
echo "RPM_OVN_HOST: $RPM_OVN_HOST"

popd 2>/dev/null
