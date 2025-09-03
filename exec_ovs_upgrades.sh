#!/bin/bash

# script to kick off upgrade tests
# example commands to use

##### Example below upgrades from RHEL-7.6-updates-20190722.1 to RHEL-7.7-updates-20190905.0, target openvswitch RPM under test based on 2.9.0, with SELinux enabled, ovs datapath, DON'T skip traffic tests, don't use latest rhel repo

# ./ovs_upgrade_tests_exec.sh RHEL-7.6-updates-20190722.1 RHEL-7.7-updates-20190905.0 2.9.0 enabled ovs <no no>


# ./ovs_upgrade_tests_exec.sh RHEL-7.5-updates-20181015.0 RHEL-7.6-updates-20190306.0 2.9.0 enabled ovs yes yes
# ./ovs_upgrade_tests_exec.sh RHEL-7.5-updates-20181015.0 RHEL-7.6-updates-20190306.0 2.9.0 enabled dpdk yes yes
# ./ovs_upgrade_tests_exec.sh RHEL-7.5-updates-20181015.0 RHEL-7.6-updates-20190306.0 2.9.0 enabled ovs yes no
# ./ovs_upgrade_tests_exec.sh RHEL-7.5-updates-20181015.0 RHEL-7.6-updates-20190306.0 2.9.0 enabled ovs no no
# ./ovs_upgrade_tests_exec.sh RHEL-7.5-updates-20181015.0 RHEL-7.6-updates-20190306.0 2.9.0 enabled ovs no yes

#set -x
# note that DPDK versions available are listed at https://github.com/ctrautma/vmscripts/blob/master/setup_rpms.sh

# Currently available:
#[root@localhost dpdkrpms]# ls  /root/dpdkrpms/
#1711-15  1811-2  el8-1811-2

dbg_flag=${dbg_flag=:-"set -x"}
$dbg_flag

fdp_version="FDP 20.B"
dpdk_version_info="1811-4"
starting_compose=$1
ending_compose=$2
ovs_rpm_version=$3
selinux_setting=$4
test_type=$5

skip_traffic_tests_value=$6
if [[ $# -lt 6 ]]; then skip_traffic_tests_value="no"; fi

# For latest RHEL-7.X (non-RHEL 8) compose when other repo links unavailable
# use_latest_rhel_repo typically only used when pointing to RHEL release still under test and not yet released
use_latest_rhel_repo_value=$7
if [[ $# -lt 7 ]]; then use_latest_rhel_repo_value="no"; fi
#openvswitch_rpm="http://download.devel.redhat.com/brewroot/packages/openvswitch/2.9.0/124.el7fdp/x86_64/openvswitch-2.9.0-124.el7fdp.x86_64.rpm"
openvswitch_rpm="http://download.eng.bos.redhat.com/brewroot/packages/openvswitch2.11/2.11.0/48.el7fdp/x86_64/openvswitch2.11-2.11.0-48.el7fdp.x86_64.rpm"
#openvswitch_rpm="http://download.devel.redhat.com/brewroot/packages/openvswitch2.11/2.11.0/21.el8fdp/x86_64/openvswitch2.11-2.11.0-21.el8fdp.x86_64.rpm"
openvswitch_selinux_rpm="http://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/15.el7fdp/noarch/openvswitch-selinux-extra-policy-1.0-15.el7fdp.noarch.rpm"
#openvswitch_selinux_rpm="http://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/18.el8fdp/noarch/openvswitch-selinux-extra-policy-1.0-18.el8fdp.noarch.rpm"
container_selinux_rpm="http://download.devel.redhat.com/brewroot/packages/container-selinux/2.77/1.el7_6/noarch/container-selinux-2.77-1.el7_6.noarch.rpm"
openvswitch_rpm_value=$(echo $openvswitch_rpm | awk -F "/" '{print $NF}')

if [[ $# -lt 5 ]]; then
	echo "You must provide five arguments: starting compose, ending compose, OVS version, selinux setting (enabled or disabled), test type (ovs or dpdk), optional: skip traffic tests (yes or no, no is default) use latest RHEL compose (yes or no, no is default)"
	echo "Example: $0 RHEL-7.4-updates-20180228.0 RHEL-7.5 2.10.0 disabled dpdk"
	exit
fi

if [[ "$selinux_setting" == "disabled" ]]; then
	selinux_setting="no"
elif [[ "$selinux_setting" == "enabled" ]]; then
	selinux_setting="yes"
else
	echo "Please specify enabled or disabled for SELinux setting"
	exit 0
fi

if [[ "$test_type" == "ovs" ]]; then
	use_dpdk_setting="no"
elif [[ "$test_type" == "dpdk" ]]; then
	use_dpdk_setting="yes"
else
	echo "Please specify ovs or dpdk for test type"
	exit 0
fi

if [[ "$test_type" == "ovs" ]] && [[ "$skip_traffic_tests_value" == "no" ]]; then
	whiteboard_text="$fdp_version, OVS kernel datapath upgrade test WITH TRAFFIC TESTS"
elif [[ "$test_type" == "dpdk" ]] && [[ "$skip_traffic_tests_value" == "no" ]]; then
	whiteboard_text="$fdp_version, OVS netdev datapath upgrade test WITH TRAFFIC TESTS"
elif [[ "$test_type" == "ovs" ]] && [[ "$skip_traffic_tests_value" == "yes" ]]; then
	whiteboard_text="$fdp_version, OVS kernel datapath upgrade test NO TRAFFIC TESTS"
elif [[ "$test_type" == "dpdk" ]] && [[ "$skip_traffic_tests_value" == "yes" ]]; then
	whiteboard_text="$fdp_version, OVS netdev datapath upgrade test NO TRAFFIC TESTS"
fi

sedeasy ()
{
sed -i "s/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3
}

#if [[ "$test_type" == "ovs" ]]; then
	#xml_file_list=${xml_file_list:-"template_upgrade_ovs_lp_to_lp.xml template_upgrade_ovs_lp_to_latest.xml template_upgrade_ovs_lp_to_target_package.xml"}
	xml_file_list=${xml_file_list:-"template_upgrades_lp_to_target_package.xml"}
	#xml_file_list=${xml_file_list:-"template_upgrade_ovs_lp_to_lp.xml"}
#elif [[ "$test_type" == "dpdk" ]]; then
#	xml_file_list=${xml_file_list:-"template_upgrade_dpdk_lp_to_lp.xml template_upgrade_dpdk_lp_to_latest.xml template_upgrade_dpdk_lp_to_target_package.xml"}
	#xml_file_list=${xml_file_list:-"template_upgrade_dpdk_lp_to_lp.xml"}
#else
#	echo "Please specify ovs or dpdk for test type"
#	exit 0
#fi

while true; do
    read -p "Have you reviewed the template XML files for accuracy?  Check DPDK version info and make sure it matches one listed in https://github.com/ctrautma/vmscripts/blob/master/setup_rpms.sh (y/n)" yn
    case $yn in
        [Yy]* ) pushd /home/ralongi/Documents/ovs_testing/xml_files || return;
				for file in $xml_file_list; do
					new_filename=$(echo $file | sed 's/template_//g')
					/bin/cp -f $file $new_filename;
					if [[ $(echo "$starting_compose" | awk -F "-" '{print $2}') == "7.3" ]]; then
						sedeasy '<param name="skip_test1" value="no"/>' '<param name="skip_test1" value="yes"/>' "$new_filename"
					fi
					sedeasy "whiteboard_text" "$whiteboard_text" "$new_filename";
					sedeasy "use_dpdk_setting" "$use_dpdk_setting" "$new_filename";
					sedeasy "dpdk_version_info" "$dpdk_version_info" "$new_filename";					
					sedeasy "starting_compose" "$starting_compose" "$new_filename";
					sedeasy "ending_compose" "$ending_compose" "$new_filename";
					sedeasy "openvswitch_rpm_location" "$openvswitch_rpm" "$new_filename";
					sedeasy "openvswitch_rpm_value" "$openvswitch_rpm_value" "$new_filename";
					sedeasy "openvswitch_selinux rpm_value" "$openvswitch_selinux_rpm" "$new_filename";
					sedeasy "skip_traffic_tests_value" "$skip_traffic_tests_value" "$new_filename";
					sedeasy "use_latest_rhel_repo_value" "$use_latest_rhel_repo_value" "$new_filename";
					sedeasy "dbg_flag_value" "$dbg_flag" "$new_filename";
					for i in $(grep "SELinux Enabled:" "$new_filename"); do
						sedeasy "selinux_setting" "$selinux_setting" "$new_filename"
					done
					for i in $(grep selinux_enable "$new_filename"); do
						sedeasy "selinux_setting" "$selinux_setting" "$new_filename"
					done
					sedeasy "ovs_rpm_version_temp" "$ovs_rpm_version" "$new_filename"
					grep "ending_compose" "$new_filename";
					grep "$ending_compose" "$new_filename";					
					bkr job-submit "$new_filename"
				done
				popd 2>/dev/null;
        		exit;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
exit

