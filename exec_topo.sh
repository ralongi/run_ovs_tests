#!/bin/bash

# topo
# note that Server machine info is listed first, Client second

# set VM image to rhel8.4.qcow2 when running RHEL-9 compose due to problems installing netperf on RHEL-9 guest
#if [[ $(echo $COMPOSE | grep RHEL-9) ]]; then VM_IMAGE="rhel8.4.qcow2"; fi

dbg_flag=${dbg_flag:-"set -x"}
$dbg_flag
image_mode=${image_mode:-"yes"}
NAY="${NAY:-"no"}"
PVT="${PVT:-"no"}"
GET_NIC_WITH_MAC="${GET_NIC_WITH_MAC:-"yes"}"

COMPOSE_VER=$(echo $COMPOSE | awk -F '-' '{print $2}')
COMPOSE_MAJOR_VER=$(echo $COMPOSE | awk -F '-' '{print $2}' | awk -F '.' '{print $1}')
if [[ $ovs_env == "ovs-dpdk" ]]; then
    ver_comp_result_file=version_compare_result.txt
    rpmdev-vercmp $COMPOSE_VER 8.8.0
    echo $? | tee $ver_comp_result_file
    # set VM image to rhel8.6.qcow2 when running RHEL-8 compose -ge 8.8 due to https://issues.redhat.com/browse/RHEL-7165
    # only affects RHEL-8, ovs-dpdk with guest running RHEL-8.8 and higher 
    if [[ $(echo $COMPOSE_VER | awk -F "." '{print $1}') -eq 8 ]]; then
        if [[ $(cat $ver_comp_result_file) -eq 0 ]] || [[ $(cat $ver_comp_result_file) -eq 11 ]]; then
            VM_IMAGE="rhel8.6.qcow2"
        fi
    fi
    # use 8.6 VM image with RHEL-9.2 due to https://bugzilla.redhat.com/show_bug.cgi?id=2184976
    if [[ $COMPOSE_VER == "9.2.0" ]]; then
        VM_IMAGE="rhel8.6.qcow2"
    fi
    rm -f $ver_comp_result_file
fi

ovs_rpm_name=$(echo $RPM_OVS | awk -F "/" '{print $NF}')
ovs_rpm_stream_ver=$(echo $ovs_rpm_name | awk -F "-" '{print $1}' | sed 's/openvswitch//g' | tr -d .)
if [[ $(echo $ovs_rpm_stream_ver | wc -c) -lt 4 ]]; then ovs_rpm_stream_ver=$(echo $ovs_rpm_stream_ver"0"); fi
pushd ~/temp
driver=$1
mlx_card_type=$(echo $2 | tr '[:lower:]' '[:upper:]')
OVS_TOPO=${OVS_TOPO:-"ovs_all"}
GUEST_TYPE=${GUEST_TYPE:-"all"}
mlx_card_model=${mlx_card_model:-"DX"}
use_hpe_synergy=${use_hpe_synergy:-"no"}
HOST_TESTS_ONLY=${HOST_TESTS_ONLY:-"no"}
product="cpe:/o:redhat:enterprise_linux"
retention_tag="active+1"

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

if [[ "$driver" == *"arm"* ]]; then
	export GUEST_TYPE="container"
fi

#if [[ "$*" == *"cpu"* ]]; then
#	export OVS_TOPO="ovs_test_ns_enable_nomlockall_CPUAffinity_test"
#fi

compose_version=$(echo $COMPOSE | awk -F "-" '{print $2}' | awk -F "." '{print $1}')

extra_packages="--param=rpm_driverctl=$RPM_DRIVERCTL --param=RPM_OVS_TCPDUMP_PYTHON=$RPM_OVS_TCPDUMP_PYTHON --param=RPM_OVS_TCPDUMP_TEST=$RPM_OVS_TCPDUMP_TEST"

if [[ $# -lt 1 ]]; then
	echo "Please enter the driver name"
	echo "Example: $0 ixgbe"
	exit 0
fi

# Can either add ovs-dpdk as third argument to ./exec_topo.sh or export ovs_env="ovs-dpdk" in terminal window
if [[ "$*" == *"ovs_env="* ]]; then
	export ovs_env=$(echo "$*" | awk -F 'ovs_env=' '{print $NF}')
fi

# set VM image to rhel8.6.qcow2 when ovs_env=ovs-dpdk until fix for https://bugzilla.redhat.com/show_bug.cgi?id=2184976 is merged
#if [[ $ovs_env == "ovs-dpdk" ]]; then VM_IMAGE=rhel8.6.qcow2; fi

if [[ $(echo $mlx_card_type | grep -i cx6) ]]; then
	if [[ "$*" == *"dx"* ]] ||  [[ "$*" == *"DX"* ]]; then
		export mlx_card_model="DX"
	elif [[ "$*" == *"lx"* ]] ||  [[ "$*" == *"LX"* ]]; then
		export mlx_card_model="LX"
	fi
fi

mlx_card_model=$(echo $mlx_card_model | tr '[:lower:]' '[:upper:]')

if [[ -z "$ovs_env" ]]; then
	export ovs_env="kernel"
fi

# For now, run both kernel and ovs-dpdk tests
# export ovs_env="all"

if [[ $ovs_rpm_stream_ver -lt 216 ]]; then
	OVS_SKIP_TESTS=$BONDING_CPU_TESTS
else
	OVS_SKIP_TESTS=$BONDING_TESTS
fi

if [[ "$driver" == *"mlx5_core"* ]] || [[ "$driver" == *"ixgbe"* ]]; then
	OVS_SKIP_TESTS+=" ovs_test_container_vlan"
fi

# i40e
if [[ "$driver" == "i40e" ]]; then
	card_info="I40E"
	server="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
	client="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
	server_driver="sfc"
	client_driver="i40e"
	SERVER_NIC_MAC_STRING="00:0f:53:7c:b2:70" #00:0f:53:7c:b2:71"
	CLIENT_NIC_MAC_STRING="3c:fd:fe:ad:86:b4" #3c:fd:fe:ad:86:b5"
elif [[ "$driver" == "e810_ice" ]]; then
	server="003-r760-ee58u06.anl.eng.rdu2.dc.redhat.com"
	client="004-r760-ee58u08.anl.eng.rdu2.dc.redhat.com"
	SERVER_NIC_MAC_STRING="30:3e:a7:0b:37:4c" #30:3e:a7:0b:37:4d
	CLIENT_NIC_MAC_STRING="30:3e:a7:0b:2a:0c" #30:3e:a7:0b:2a:0d	
	server_driver="ice"
	client_driver="ice"
	card_info="E810 ICE"
	
# Intel E830 ice card
elif [[ "$driver" == "e830_ice" ]]; then
	server="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
	client="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="ice"
	server_nic_test="ens6f0np0"
	client_nic_test="eno4np1"
	card_info="E830 ICE"
	
# Intel GNR-D e825 ice card
elif [[ "$driver" == "e825_ice" ]]; then
	server="wsfd-advnetlab127.anl.eng.bos2.dc.redhat.com"
	client="intel-kaseyville-gnr-d-02.khw.eng.bos2.dc.redhat.com"
	server_driver="ice"
	client_driver="ice"
	server_nic_test="ens1f1"
	client_nic_test="enp19s0"
	card_info="E825 ICE"
	
# mlx5_core CX5
elif [[ "$driver" == "mlx5_core" ]] && [[ "$mlx_card_type" == "CX5" ]]; then
	server="003-r760-ee58u06.anl.eng.rdu2.dc.redhat.com"
	client="004-r760-ee58u08.anl.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	SERVER_NIC_MAC_STRING="b8:59:9f:c4:ad:f6" #b8:59:9f:c4:ad:f7
	CLIENT_NIC_MAC_STRING="b8:59:9f:c4:ad:e6" #b8:59:9f:c4:ad:e7
	mlx_card_type="CX5"
	card_info="CX5"
# mlx5_core CX6
elif [[ "$driver" == "mlx5_core" ]] && [[ "$mlx_card_type" == "CX6" ]]; then
	if [[ $mlx_card_model == "DX" ]]; then
		server="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
		client="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
		server_driver="mlx5_core"
		client_driver="mlx5_core"
		SERVER_NIC_MAC_STRING="10:70:fd:a3:7c:98" #10:70:fd:a3:7c:99
		CLIENT_NIC_MAC_STRING="04:3f:72:b2:c0:ac" #04:3f:72:b2:c0:ad
		echo "${SERVER_NIC_MAC_STRING}","${CLIENT_NIC_MAC_STRING}" > ~/temp/nic_mac_string.txt
		card_info="CX6-DX"
	fi
	if [[ $mlx_card_model == "LX" ]]; then
		server="wsfd-advnetlab36.anl.eng.rdu2.dc.redhat.com"
		client="wsfd-advnetlab35.anl.eng.rdu2.dc.redhat.com"
		server_driver="i40e"
		client_driver="mlx5_core"
		card_info="CX6-LX"
	fi
	
elif [[ "$driver" == "mlx5_core" ]] && [[ "$mlx_card_type" == "CX7" ]]; then
	server="002-r760-ee58u04.anl.eng.rdu2.dc.redhat.com"
	client="001-r760-ee58u02.anl.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	SERVER_NIC_MAC_STRING="04:3f:72:b2:c0:ac" #04:3f:72:b2:c0:ad
	CLIENT_NIC_MAC_STRING="10:70:fd:a3:7c:98" #10:70:fd:a3:7c:99
	card_info="CX7"
	
# mlx5_core BF2
elif [[ "$driver" == "mlx5_core" ]] && [[ "$mlx_card_type" == "BF2" ]]; then
	server="netqe29.knqe.eng.rdu2.dc.redhat.com"
	client="netqe30.knqe.eng.rdu2.dc.redhat.com"
	server_driver="i40e"
	client_driver="mlx5_core"
	netscout_pair1="netqe29_p3p1 netqe30_p7p1"
	netscout_pair2="netqe29_p3p2 netqe30_p7p2"
	if [[ $compose_version -gt 8 ]]; then
		server_nic_test="ens3f0"
		client_nic_test="ens7f0np0"
	else
		server_nic_test="ens3f0"
		client_nic_test="ens7f0"
	fi
	card_info="BF2"
	
# mlx5_core BF3
elif [[ "$driver" == "mlx5_core" ]] && [[ "$mlx_card_type" == "BF3" ]]; then
	#server="netqe27.knqe.eng.rdu2.dc.redhat.com"
	#client="netqe28.knqe.eng.rdu2.dc.redhat.com"
	#server_driver="mlx5_core"
	#client_driver="mlx5_core"
	server="netqe31.knqe.eng.rdu2.dc.redhat.com"
	client="netqe56.knqe.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	SERVER_NIC_MAC_STRING="ec:0d:9a:44:36:14" #ec:0d:9a:44:36:15
	CLIENT_NIC_MAC_STRING="a0:88:c2:d3:4f:18" #a0:88:c2:d3:4f:19
	#if [[ $compose_version -gt 8 ]]; then
	#	server_nic_test="enp130s0f0np0"
	#	client_nic_test="ens1f0np0"
	#else
	#	server_nic_test="ens3f0"
	#	client_nic_test="ens7f0"
	cfi
	card_info="BF3"
	
# if no mlx_card_type value, default to mlx5_core CX6
elif [[ "$driver" == "mlx5_core" ]] && [[ -z "$mlx_card_type" ]]; then
	mlx_card_type="CX6"
	server="netqe25.knqe.eng.rdu2.dc.redhat.com"
	client="netqe24.knqe.eng.rdu2.dc.redhat.com"
	if [[ $compose_version -gt 8 ]]; then
		server_nic_test="enp4s0f0np0"
		client_nic_test="enp4s0f0np0"
	else
		server_nic_test="enp4s0f0"
		client_nic_test="enp4s0f0"
	fi
	
### ARM aarch64 tests with Netscout
elif [[ "$driver" == "mlx5_core_arm" ]]; then
	#server="ampere-mtsnow-01.knqe.eng.rdu2.dc.redhat.com"
	#client="ampere-mtsnow-02.knqe.eng.rdu2.dc.redhat.com"
	#server_driver="mlx5_core"
	#client_driver="mlx5_core"
	mlx_card_type="CX6-DX"
	client="netqe49.knqe.eng.rdu2.dc.redhat.com" # ARM system
	#client="netqe47.knqe.eng.rdu2.dc.redhat.com"
	#client="netqe48.knqe.eng.rdu2.dc.redhat.com"
	server="netqe24.knqe.eng.rdu2.dc.redhat.com" #x86_64 system
	server_driver="mlx5_core"
	client_driver="mlx5_core"
	SERVER_NIC_MAC_STRING="0c:42:a1:22:a3:46" #0c:42:a1:22:a3:47
	CLIENT_NIC_MAC_STRING="94:6d:ae:d9:23:f4" #94:6d:ae:d9:23:f5	
	#server_pciid="15b3:1021" #CX7
	#server_pciid="15b3:101d" #CX6-DX
	#client_pciid="8086:1592" #E810
	export RPM_OVS_AARCH64=${RPM_OVS_AARCH64:-$(echo $RPM_OVS | sed 's/x86_64/aarch64/g')}
	export RPM_OVS_TCPDUMP_PYTHON_AARCH64=${RPM_OVS_TCPDUMP_PYTHON_AARCH64:-$(echo $RPM_OVS_TCPDUMP_PYTHON | sed 's/x86_64/aarch64/g')}
	#export RPM_OVS_TCPDUMP_TEST_AARCH64=$(echo $RPM_OVS_TCPDUMP_TEST | sed 's/x86_64/aarch64/g')	
	export ovs_rpm_name=$(echo $RPM_OVS_AARCH64 | awk -F "/" '{print $NF}')
	#netscout_pair1="NETQE24_P4P1 NETQE49_CX7_P5P1" # netqe24 CX5 to netqe49 CX7 ARM
	#netscout_pair2="NETQE24_P4P2 NETQE49_CX7_P5P2" # netqe24 CX5 to netqe49 CX7
	GUEST_TYPE="container"
	if [[ $compose_version -gt 8 ]]; then
		server_nic_test="enp130s0f0np0"
		client_nic_test="enP2p2s0f0np0"
	else
		server_nic_test="enp130s0f0"
		client_nic_test="enP2p2s0f0"
	fi
	card_info="ARM CX6-DX"
	
elif [[ "$driver" == "ixgbe" ]]; then
	server="netqe53.knqe.eng.rdu2.dc.redhat.com"
	client="netqe50.knqe.eng.rdu2.dc.redhat.com"
	server_driver="sfc"
	client_driver="ixgbe"
	card_info="IXGBE"
	HOST_TESTS_ONLY="yes"

### Cisco enic
elif [[ "$driver" == "enic" ]]; then
	server="netqe22.knqe.eng.rdu2.dc.redhat.com"
	client="netqe26.knqe.eng.rdu2.dc.redhat.com"
	server_driver="i40e"
	client_driver="enic"
	netscout_pair1="NETQE26_ENP9S0 NETQE22_P6P1"
	netscout_pair2="NETQE26_ENP10S0 NETQE22_P6P2"
	if [[ $COMPOSE_MAJOR_VER -ge 10 ]]; then
		server_nic_test="enp3s0f0np0"
	else
		server_nic_test="enp3s0f0"
	fi	
	client_nic_test="enp9s0"
	HOST_TESTS_ONLY="yes"
	card_info="ENIC"
	SERVER_NIC_MAC_STRING="40:a6:b7:0b:d0:ac" #40:a6:b7:0b:d0:ad
	CLIENT_NIC_MAC_STRING="00:5d:73:7d:36:75" #00:5d:73:7d:36:76
	
elif [[ "$driver" == "qede" ]]; then
	server="netqe26.knqe.eng.rdu2.dc.redhat.com"
	client="netqe22.knqe.eng.rdu2.dc.redhat.com"
	server_driver="enic"
	client_driver="qede"
	netscout_pair1="NETQE26_ENP9S0 NETQE22_P7P1"
	netscout_pair2="NETQE26_ENP10S0 NETQE22_P7P2"
	server_nic_test="enp9s0"
	client_nic_test="enp5s0f0"
	HOST_TESTS_ONLY="yes"
	card_info="QEDE"
	SERVER_NIC_MAC_STRING="00:5d:73:7d:36:75" #00:5d:73:7d:36:76
	CLIENT_NIC_MAC_STRING="00:0e:1e:f0:e4:48" #00:0e:1e:f0:e4:49
	
elif [[ "$driver" == "bnxt_en" ]]; then
	server="netqe26.knqe.eng.rdu2.dc.redhat.com"
	client="netqe22.knqe.eng.rdu2.dc.redhat.com"
	server_driver="enic"
	client_driver="bnxt_en"
	netscout_pair1="NETQE26_ENP9S0 NETQE22_P4P1"
	netscout_pair2="NETQE26_ENP10S0 NETQE22_P4P2"	
	server_nic_test="enp9s0"
	client_nic_test="enp130s0f0np0"
	HOST_TESTS_ONLY="yes"
	card_info="BNXT_EN"
	SERVER_NIC_MAC_STRING="00:5d:73:7d:36:75" #00:5d:73:7d:36:76
	CLIENT_NIC_MAC_STRING="00:0a:f7:b7:09:50" #00:0a:f7:b7:09:51
	
# Intel ice E810 STS card	
elif [[ "$driver" == "sts" ]]; then
	server="netqe22.knqe.eng.rdu2.dc.redhat.com"
	client="netqe29.knqe.eng.rdu2.dc.redhat.com"
	SERVER_NIC_MAC_STRING="40:a6:b7:0b:d0:ac"
	CLIENT_NIC_MAC_STRING="00:e0:ed:f0:0e:60"
	server_driver="i40e"
	client_driver="ice"
	netscout_pair1="NETQE29_STS2_1 NETQE22_P6P1"
	netscout_pair2="NETQE29_STS2_2 NETQE22_P6P2"
	#server_nic_test="ens1f0"
	#client_nic_test="ens8f0"
	card_info="E810 STS2"	
	
# Intel i40e X710 T4L card	
elif [[ "$driver" == "t4l" ]]; then
	server=${server:-"wsfd-netdev73.ntdv.lab.eng.bos.redhat.com"}
	client=${client:-"wsfd-netdev71.ntdv.lab.eng.bos.redhat.com"}
	server_driver=${server_driver:-"i40e"}
	client_driver=${server_driver:-"i40e"}
	#server_nic_test="enp3s0f0"
	#client_nic_test="enp4s0f0"
	card_info="X710 T4L"
	
# Intel ice E810 Empire Flats card	
elif [[ "$driver" == "empire" ]]; then
	server="netqe25.knqe.eng.rdu2.dc.redhat.com"
	client="netqe40.knqe.eng.rdu2.dc.redhat.com"
	server_driver="mlx5_core"
	client_driver="ice"
	netscout_pair1="NETQE25_P5P1 NETQE40_P0P1"
	netscout_pair2="NETQE25_P5P2 NETQE40_P0P2"
	client_nic_test="eno3"
	
	if [[ $compose_version -gt 8 ]]; then
		server_nic_test="enp6s0f0np0"
	else
		server_nic_test="enp6s0f0"
	fi
	card_info="E810 Empire Flats"
	
# Broadcom BMC57504 tests	
elif [[ "$driver" == "bmc57504" ]]; then
	server="wsfd-advnetlab151.anl.lab.eng.bos.redhat.com"
	client="wsfd-advnetlab154.anl.lab.eng.bos.redhat.com"
	server_driver="mlx5_core"
	client_driver="bnxt_en"
	client_nic_test="ens5f0np0"
	if [[ $compose_version -gt 8 ]]; then
		server_nic_test="ens4f0np0"
	else
		server_nic_test="ens4f0"
	fi
	special_info="Broadcom BMC57504 NIC https://issues.redhat.com/browse/FDPQE-450"
	
# HPE Synergy 6820C qede
elif [[ "$driver" == "6820c" ]]; then
	server="hpe-netqe-syn480g10-02.knqe.eng.rdu2.dc.redhat.com"
	client="hpe-netqe-syn480g10-01.knqe.eng.rdu2.dc.redhat.com"
	server_driver="i40e"
	client_driver="qede"
	client_nic_test="ens1f0"
	server_nic_test="ens1f0"
	card_info="HPE Synergy 6820C qede"

# Intel E810 for backplane
elif [[ "$driver" == "e810_ice_bp" ]]; then
	server="wsfd-advnetlab241-intel-ptl.anl.eng.bos2.dc.redhat.com"
	client="wsfd-advnetlab241.anl.eng.bos2.dc.redhat.com"
	NAY="no"
	PVT="no"
	GET_NIC_WITH_MAC="yes"
	CLIENT_NIC_MAC_STRING="88:dc:97:52:28:a0" # 88:dc:97:52:28:a1"
	SERVER_NIC_MAC_STRING="88:dc:97:52:28:9c" # 88:dc:97:52:28:9d"
	server_driver="ice"
	client_driver="ice"
	card_info="E810 for Backplane"

# Intel E823 for backplane
elif [[ "$driver" == "e823_ice_bp" ]]; then
	server="wsfd-advnetlab241.anl.eng.bos2.dc.redhat.com"
	client="wsfd-advnetlab241-intel-ptl.anl.eng.bos2.dc.redhat.com"
	NAY="no"
	PVT="no"
	GET_NIC_WITH_MAC="yes"
	CLIENT_NIC_MAC_STRING="88:dc:97:52:28:9c" # 88:dc:97:52:28:9d"
	SERVER_NIC_MAC_STRING="88:dc:97:52:28:a0" # 88:dc:97:52:28:a1"
	server_driver="ice"
	client_driver="ice"
	card_info="E823 for Backplane"

# Intel E823 for SFP
elif [[ "$driver" == "e823_ice_sfp" ]]; then
	server="wsfd-advnetlab242.anl.eng.bos2.dc.redhat.com"
	client="wsfd-advnetlab241-intel-ptl.anl.eng.bos2.dc.redhat.com"
	NAY="no"
	PVT="no"
	GET_NIC_WITH_MAC="yes"
	CLIENT_NIC_MAC_STRING="88:dc:97:52:28:9e" # 88:dc:97:52:28:9f"
	SERVER_NIC_MAC_STRING="40:a6:b7:0e:43:d0" # 40:a6:b7:0e:43:d1"
	server_driver="i40e"
	client_driver="ice"
	card_info="E823 for SFP"
fi

# load specific kernel job
#brew_build=http://download.eng.bos.redhat.com/brewroot/work/tasks/3943/49363943/

# To obtain the info for the brew build:
# - go to original task ID provided (in Jira, etc.)
# - click on buildArch src.rpm for the target arch under Descendants
# - right click kernel rpm link: http://download.eng.bos.redhat.com/brewroot/work/tasks/4549/37664549/kernel-4.18.0-315.el8.bz1944818v1.x86_64.rpm
# - for above kernel, BUILDID value is: 49363943
# OR use link with runtest: -B 49363943 or --Brew=49363943

#	cat ovs.list | egrep "openvswitch/topo" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --product=$product --retention-tag=$retention_tag --machine=$server,$client -B $brew_build --systype=machine,machine  --param=dbg_flag="$dbg_flag" --param=OVS_TOPO=$OVS_TOPO --param=selinux_enable=$selinux_enable --param=NAY=$NAY --param=GUEST_TYPE=$GUEST_TYPE --param=PVT=$PVT --param=image_name=$image_name --param=SRC_NETPERF=$SRC_NETPERF --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY_RHEL8 --param=RPM_OVS=$RPM_OVS $(echo $extra_packages) --param=OVS_SKIP_CLEANUP_ENV=yes --param=OVS_SKIP="$OVS_SKIP_TESTS" --param=netscout_pair1="$netscout_pair1" --param=netscout_pair2="$netscout_pair2" --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/topo, Client driver: $client_driver, Server driver: $server_driver, Driver under test: $client_driver ($mlx_card_type), ovs_env: $ovs_env, OVS_TOPO: $OVS_TOPO $special_info" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"

if [[ "$arch_test" == "x86_64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/topo" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --machine=$server,$client --systype=machine,machine  $(echo "$zstream_repo_list") --Brew=$brew_target --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=OVS_TOPO=$OVS_TOPO --param=HOST_TESTS_ONLY=$HOST_TESTS_ONLY --param=ovs_env=$ovs_env --param=SELINUX=$SELINUX --param=AVC_ERROR=+no_avc_check --param=GUEST_TYPE=$GUEST_TYPE --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING=$(echo $SERVER_NIC_MAC_STRING),$(echo $CLIENT_NIC_MAC_STRING) --param=image_name=$VM_IMAGE --param=SRC_NETPERF=$SRC_NETPERF --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=rpm_driverctl=$RPM_DRIVERCTL --param=RPM_OVS_TCPDUMP_PYTHON=$RPM_OVS_TCPDUMP_PYTHON --param=RPM_OVS_TCPDUMP_TEST=$RPM_OVS_TCPDUMP_TEST --param=OVS_SKIP_CLEANUP_ENV=yes --param=OVS_SKIP="$OVS_SKIP_TESTS" --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/topo, Client driver: $client_driver, Server driver: $server_driver, Driver under test: $client_driver ($card_info), ovs_env: $ovs_env, OVS_TOPO: $OVS_TOPO $special_info \`topo Image Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	else
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/topo" | runtest --ks-meta "packages=kernel-64k" --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64" --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$server,$client --systype=machine,machine  $(echo "$zstream_repo_list") --Brew=$brew_target --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=OVS_TOPO=$OVS_TOPO --param=HOST_TESTS_ONLY=$HOST_TESTS_ONLY --param=ovs_env=$ovs_env --param=SELINUX=$SELINUX --param=AVC_ERROR=+no_avc_check --param=GUEST_TYPE=$GUEST_TYPE --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="${SERVER_NIC_MAC_STRING}","${CLIENT_NIC_MAC_STRING}" --param=image_name=$VM_IMAGE --param=SRC_NETPERF=$SRC_NETPERF --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=RPM_OVS=$RPM_OVS --param=rpm_driverctl=$RPM_DRIVERCTL --param=RPM_OVS_TCPDUMP_PYTHON=$RPM_OVS_TCPDUMP_PYTHON --param=RPM_OVS_TCPDUMP_TEST=$RPM_OVS_TCPDUMP_TEST --param=OVS_SKIP_CLEANUP_ENV=yes --param=OVS_SKIP="$OVS_SKIP_TESTS" --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/topo, Client driver: $client_driver, Server driver: $server_driver, Driver under test: $client_driver ($card_info), ovs_env: $ovs_env, OVS_TOPO: $OVS_TOPO $special_info \`topo Package Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	fi
elif [[ "$arch_test" == "aarch64" ]]; then
	if [[ $image_mode == "yes" ]]; then
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/topo" | runtest --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64,aarch64" --bootc=$COMPOSE --nrestraint --autopath --kernel-options "crashkernel=640M" --packages="virt-viewer,virt-install,libvirt-daemon,virt-manager,libvirt,qemu-kvm,libguestfs,guestfs-tools,gcc,gcc-c++,glibc-devel,net-tools,zlib-devel,pciutils,lsof,tcl,tk,git,wget,nano,driverctl,dpdk,dpdk-tools,ipv6calc,wireshark-cli,nmap-ncat,python3-pip,python3-scapy,rpmdevtools,git,netperf,dnsmasq,$locate_pkg" --product=$product --retention-tag=$retention_tag --machine=$server,$client --systype=machine,machine  $(echo "$zstream_repo_list") --Brew=$brew_target --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=OVS_TOPO=$OVS_TOPO --param=HOST_TESTS_ONLY=$HOST_TESTS_ONLY --param=ovs_env=$ovs_env --param=SELINUX=$SELINUX --param=AVC_ERROR=+no_avc_check --param=GUEST_TYPE=$GUEST_TYPE --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="0c:42:a1:22:a3:46","94:6d:ae:d9:23:f4" --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=mh-RPM_OVS=$RPM_OVS,$RPM_OVS_AARCH64 --param=mh-RPM_OVS_TCPDUMP_PYTHON=$RPM_OVS_TCPDUMP_PYTHON,$RPM_OVS_TCPDUMP_PYTHON_AARCH64 --param=rpm_driverctl=$RPM_DRIVERCTL --param=RPM_OVS_TCPDUMP_TEST=$RPM_OVS_TCPDUMP_TEST --param=OVS_SKIP_CLEANUP_ENV=yes --param=OVS_SKIP="$OVS_SKIP_TESTS" --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/topo, Client driver: $client_driver, Server driver: $server_driver, Driver under test: $client_driver ($card_info), ovs_env: $ovs_env, OVS_TOPO: $OVS_TOPO $special_info \`topo Image Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	else
		cat ~/git/my_fork/kernel/networking/tools/runtest-network/ovs.list | egrep "openvswitch/topo" | runtest --ks-meta "packages=kernel-64k" --fetch-url kernel@https://gitlab.cee.redhat.com/kernel-qe/kernel/-/archive/master/kernel-master.tar.bz2 $COMPOSE --arch="x86_64,aarch64" --kernel-options "crashkernel=640M" --product=$product --retention-tag=$retention_tag --machine=$server,$client --systype=machine,machine  $(echo "$zstream_repo_list") --Brew=$brew_target --param=SERVERS="$server" --param=CLIENTS="$client" --param=dbg_flag="$dbg_flag" --param=OVS_TOPO=$OVS_TOPO --param=HOST_TESTS_ONLY=$HOST_TESTS_ONLY --param=ovs_env=$ovs_env --param=SELINUX=$SELINUX --param=AVC_ERROR=+no_avc_check --param=GUEST_TYPE=$GUEST_TYPE --param=NAY=$NAY --param=PVT=$PVT --param=GET_NIC_WITH_MAC=$GET_NIC_WITH_MAC --param=mh-NIC_MAC_STRING="0c:42:a1:22:a3:46","94:6d:ae:d9:23:f4" --param=mh-image_name=$VM_IMAGE,$VM_IMAGE_AARCH64 --param=SRC_NETPERF=$SRC_NETPERF --param=RPM_OVS_SELINUX_EXTRA_POLICY=$RPM_OVS_SELINUX_EXTRA_POLICY --param=mh-RPM_OVS=$RPM_OVS,$RPM_OVS_AARCH64 --param=mh-RPM_OVS_TCPDUMP_PYTHON=$RPM_OVS_TCPDUMP_PYTHON,$RPM_OVS_TCPDUMP_PYTHON_AARCH64 --param=rpm_driverctl=$RPM_DRIVERCTL --param=RPM_OVS_TCPDUMP_TEST=$RPM_OVS_TCPDUMP_TEST --param=OVS_SKIP_CLEANUP_ENV=yes --param=OVS_SKIP="$OVS_SKIP_TESTS" --param=mh-NIC_DRIVER=$server_driver,$client_driver --wb "(Server: $server, Client: $client), FDP $FDP_RELEASE, $ovs_rpm_name, $COMPOSE, openvswitch/topo, Client driver: $client_driver, Server driver: $server_driver, Driver under test: $client_driver ($card_info), ovs_env: $ovs_env, OVS_TOPO: $OVS_TOPO $special_info \`topo Package Mode\`" --insert-task="/kernel/networking/openvswitch/netscout_connect_ports {dbg_flag=set -x} {netscout_pair1=$netscout_pair1} {netscout_pair2=$netscout_pair2}" --append-task="/kernel/networking/openvswitch/crash_check {dbg_flag=set -x}"
	fi
fi

rm -f ~/git/my_fork/kernel/networking/tools/runtest-network/job*.xml
popd 2>/dev/null
