#!/bin/bash

# script to kick off OVS tests 

# set location of your git kernel tests repo:
export KERNEL_TESTS_HOME=${KERNEL_TESTS_HOME:-~/git/my_fork}

# set location of github repo
export GITHUB_HOME=${GITHUB_HOME:-~/github}

# set location of script directory
export script_directory=${script_directory:-$GITHUB_HOME/run_ovs_tests}

# requires user input for FDP relase, RHEL version and FDP stream
# example syntax: run_ovs_tests.sh 21e 8.4 2.13

dbg_flag=${dbg_flag:-"set +x"}
$dbg_flag

check_args=${check_args:-"yes"} # "export check_args=no" to skip for args to script for memory_leak_soak

display_usage()
{
	echo "This script will kick off OVS tests based on parameters provided."
	echo "Usage: $0 <FDP Release> <RHEL Version> <FDP Stream>"
	echo "Example: $0 21e 8.4 2.13"
	echo "To use a specific compose (versus using latest), first execute 'export COMPOSE=<COMPOSE_ID>' in terminal window"
	exit 0
}

if [[ $check_args != "no" ]]; then
	if [[ $# -lt 3 ]] || [[ $1 = "-h" ]] || [[ $1 = "--help" ]]	|| [[ $1 = "-?" ]]; then
		display_usage
	fi
else
	export RHEL_VER=$(echo $COMPOSE | awk -F '-' '{print $2}' | awk -F '.' '{print $1"."$2}') 
fi

if [[ -z $tests ]]; then
	echo "Please specify at least one or more tests to be run via: export tests=<name_of_test>"
	echo 'Example: export tests="topo_e810_ice topo_mlx5_core_cx5 topo_mlx5_core_cx6_dx topo_mlx5_core_cx7"'
	echo "List of frequently run tests: mcast_snoop ovs_qos forward_bpdu of_rules vm100 sanity_check power_cycle_crash ovs_upgrade topo_i40e topo_e810_ice topo_mlx5_core_cx5 topo_mlx5_core_cx6_dx topo_mlx5_core_cx6_lx topo_mlx5_core_cx7 topo_ice_sts" 
	exit 0
else
	echo "Tests to be executed: $tests"
	read -p "Would you like to proceed ? (y/n)" yn
	case $yn in
		[Yy]* ) 
				;;
		[Nn]* ) exit;;
		* ) echo "Please answer yes or no.";;
	esac
fi

# Make sure local git is up to date
pushd "$KERNEL_TESTS_HOME"/kernel/networking &>/dev/null
git status | grep 'working tree clean' || git pull > /dev/null
popd &>/dev/null

if [[ $check_args != "no" ]]; then
	export FDP_RELEASE=${FDP_RELEASE:-"$1"}
	export FDP_RELEASE=$(echo $FDP_RELEASE | tr '[:lower:]' '[:upper:]')
	export FDP_RELEASE=$(echo $FDP_RELEASE | tr -d '.')

	export RHEL_VER=${RHEL_VER:-"$2"}
	export RHEL_VER_MAJOR=$(echo $RHEL_VER | awk -F "." '{print $1}')

	export FDP_STREAM=${FDP_STREAM:-"$3"}
	export FDP_STREAM2=$(echo $FDP_STREAM | tr -d '.')
	if [[ $FDP_STREAM2 -gt 213 ]]; then
		YEAR=$(grep -i ovn fdp_package_list.sh | grep $FDP_RELEASE | awk -F "_" '{print $3}' | grep -v 213 | tail -n1)
	fi
fi

pushd "$GITHUB_HOME"/run_ovs_tests &>/dev/null
/bin/cp -f exec_my_ovs_tests_template.sh exec_my_ovs_tests.sh
sed -i "s/FDP_RELEASE_VALUE/$FDP_RELEASE/g" exec_my_ovs_tests.sh
sed -i "s/RHEL_VER_VALUE/$RHEL_VER_MAJOR/g" exec_my_ovs_tests.sh
sed -i "s/FDP_STREAM_VALUE/$FDP_STREAM2/g" exec_my_ovs_tests.sh
sed -i "s/YEAR_VALUE/$YEAR/g" exec_my_ovs_tests.sh
sed -i "s/RHEL_VER_MAJOR_VALUE/$RHEL_VER_MAJOR/g" exec_my_ovs_tests.sh

#if [[ -z $tests ]]; then
#	tests=$(grep "^OVS-$FDP_STREAM-RHEL-$RHEL_VER_MAJOR-Tests" ~/github/tools/scripts/fdp_errata_list.txt | awk -F ":" '{print $NF}')
#fi

for i in $tests; do
	if [[ $i == *"mcast_snoop"* ]]; then
		sed -i '/test_exec_mcast_snoop.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"ovs_qos"* ]]; then
		sed -i '/test_exec_ovs_qos.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"forward_bpdu"* ]]; then
		sed -i '/test_exec_forward_bpdu.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"of_rules"* ]]; then
		sed -i '/test_exec_of_rules.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"power_cycle_crash"* ]]; then
		sed -i '/test_exec_power_cycle_crash.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"ovs_upgrade"* ]]; then
		sed -i '/test_exec_ovs_upgrade.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"topo_ixgbe"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh ixgbe ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh ixgbe/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_i40e"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh i40e ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh i40e/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e810_ice"* ]] && [[ ! $(echo $i | grep bp) ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh e810_ice ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e810_ice/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e830"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh e830_ice ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e830_ice/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e825"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh 825_ice ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e825_ice/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e810_ice_bp"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh e810_ice_bp ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e810_ice_bp/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e823_ice_bp"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh e823_ice_bp ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e823_ice_bp/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_e823_ice_sfp"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh e823_ice_sfp ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh e823_ice_sfp/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_arm"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core_arm ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core_arm/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_cx5"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core cx5 ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core cx5/s/^#//g' exec_my_ovs_tests.sh
		fi		
	elif [[ $i == *"topo_mlx5_core_cx6_dx"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core cx6 dx ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core cx6 dx/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_cx6_lx"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core cx6 lx ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core cx6 lx/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_cx7"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core cx7 ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core cx7/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_bf2"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core bf2 ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core bf2/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_mlx5_core_bf3"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh mlx5_core bf3 ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh mlx5_core bf3/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_enic"* ]]; then
		if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh enic/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh enic/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_qede"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh qede/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh qede/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_bnxt_en"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh bnxt_en/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh bnxt_en/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_ice_sts"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh sts/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh sts/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_t4l"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh t4l/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh t4l/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_empire"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh ice_empire/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh ice_empire/s/^#//g' exec_my_ovs_tests.sh
		fi		
	elif [[ $i == *"topo_bmc57504"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh bnxt_en_bmc57504/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh bnxt_en_bmc57504/s/^#//g' exec_my_ovs_tests.sh
		fi
	elif [[ $i == *"topo_6820c"* ]]; then
	    if [[ $ovs_env ]]; then
			sed -i "/test_exec_topo.sh 6820c/s/^#//g ovs_env=$ovs_env/s/^#//g" exec_my_ovs_tests.sh
		else
			sed -i '/test_exec_topo.sh 6820c/s/^#//g' exec_my_ovs_tests.sh
		fi	
	elif [[ $i == *"endurance_cx5"* ]]; then
		sed -i '/test_exec_endurance.sh cx5/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"perf_ci_cx5"* ]]; then
		sed -i '/test_exec_perf_ci.sh cx5/s/^#//g' exec_my_ovs_tests.sh	
	elif [[ $i == *"endurance_cx6dx"* ]]; then
		sed -i '/test_exec_endurance.sh cx6dx/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"perf_ci_cx6dx"* ]]; then
		sed -i '/test_exec_perf_ci.sh cx6dx/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"endurance_cx6lx"* ]]; then
		sed -i '/test_exec_endurance.sh cx6lx/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"perf_ci_cx6lx"* ]]; then
		sed -i '/test_exec_perf_ci.sh cx6lx/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"endurance_bf2"* ]]; then
		sed -i '/test_exec_endurance.sh bf2/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"perf_ci_bf2"* ]]; then
		sed -i '/test_exec_perf_ci.sh bf2/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"sanity_check"* ]]; then
		sed -i '/test_exec_sanity_check.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"vm100"* ]]; then
		sed -i '/test_exec_vm100.sh/s/^#//g' exec_my_ovs_tests.sh
	elif [[ $i == *"ovs_memory_leak_soak"* ]]; then
		sed -i '/test_exec_ovs_memory_leak_soak.sh/s/^#//g' exec_my_ovs_tests.sh
	fi
done

./exec_my_ovs_tests.sh

popd &>/dev/null

echo "FDP_RELEASE: $FDP_RELEASE"
echo "RHEL_VER_MAJOR: $RHEL_VER_MAJOR"
echo "FDP_STREAM2: $FDP_STREAM2"
