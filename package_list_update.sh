#! /bin/bash

# Script to update fdp_package_list.sh which is mainly used by kernel/networking/openvswitch/ovs_upgrade

dbg_flag=${dbg_flag:-"set +x"}
$dbg_flag
# set location of github repo
github_home=${github_home:-~/github}
script_directory="$github_home"/run_ovs_tests
fdp_release=$1
if [[ $# -lt 1 ]]; then echo "Please provide FDP release designation without 'FDP' (25.C, 25.c, etc):"; read fdp_release; fi
fdp_release=$(echo "$fdp_release" | awk '{print toupper($0)}')
if [[ ! $(echo "$fdp_release" | grep '\.') ]]; then
	echo "Please include the period in the FDP release designation without 'FDP' (25.C, 25.c, etc)"
	exit 0
fi
package_file="$script_directory"/fdp_package_list.sh
fdp_release_short=$(echo $fdp_release | tr -d .)
new_package_template_file="$script_directory/new_package_list_template.sh"
new_package_list_temp_file="$script_directory/new_package_list_temp.sh"
new_package_list_file="$script_directory/new_package_list.sh"
fdp_errata_list_file=$script_directory/errata_list.txt
package_list_file=$script_directory/package_list.txt
upload_package_file=${upload_package_file:-"yes"}

batch=$(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" |awk -F '"' '{print $4}' | awk -F '/' '{print $NF}' | head -1)
errata_list=$(curl -su : --negotiate https://errata.devel.redhat.com/api/v1/batches/$batch | jq | grep id | awk '{print $NF}' | grep -v ,)

sedeasy ()
{
sed -i "s/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3
}

rm -f $new_package_list_temp_file $new_package_list_file
echo "" >> $new_package_list_file
echo "# FDP $fdp_release Packages" >> $new_package_list_file

pushd $script_directory

selinux_version=$(curl -sL https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/ | grep el7 | tail -n1 | awk -F '>' '{print $6}' | awk -F '"' '{print $2}' | tr -d /)
package_url=https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/$selinux_version/noarch/openvswitch-selinux-extra-policy-1.0-$selinux_version.noarch.rpm
http_code=$(curl --silent --head --write-out '%{http_code}' "$package_url" | grep HTTP | awk '{print $2}')
if [[ "$http_code" -ne 200 ]]; then echo "$package_url is NOT a valid link.  Exiting..."; exit 1; fi
echo "OVS_SELINUX_$fdp_release_short"_RHEL7=${package_url} >> $new_package_list_file

selinux_version=$(curl -sL https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/ | grep el8 | tail -n1 | awk -F '>' '{print $6}' | awk -F '"' '{print $2}' | tr -d /)
package_url=https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/$selinux_version/noarch/openvswitch-selinux-extra-policy-1.0-$selinux_version.noarch.rpm
http_code=$(curl --silent --head --write-out '%{http_code}' "$package_url" | grep HTTP | awk '{print $2}')
if [[ "$http_code" -ne 200 ]]; then echo "$package_url is NOT a valid link.  Exiting..."; exit 1; fi
echo "OVS_SELINUX_$fdp_release_short"_RHEL8=${package_url} >> $new_package_list_file

selinux_version=$(curl -sL https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/ | grep el9 | tail -n1 | awk -F '>' '{print $6}' | awk -F '"' '{print $2}' | tr -d /)
package_url=https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/$selinux_version/noarch/openvswitch-selinux-extra-policy-1.0-$selinux_version.noarch.rpm
http_code=$(curl --silent --head --write-out '%{http_code}' "$package_url" | grep HTTP | awk '{print $2}')
if [[ "$http_code" -ne 200 ]]; then echo "$package_url is NOT a valid link.  Exiting..."; exit 1; fi
echo "OVS_SELINUX_$fdp_release_short"_RHEL9=${package_url} >> $new_package_list_file

selinux_version=$(curl -sL https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/ | grep el10 | tail -n1 | awk -F '>' '{print $6}' | awk -F '"' '{print $2}' | tr -d /)
package_url=https://download.devel.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/$selinux_version/noarch/openvswitch-selinux-extra-policy-1.0-$selinux_version.noarch.rpm
http_code=$(curl --silent --head --write-out '%{http_code}' "$package_url" | grep HTTP | awk '{print $2}')
if [[ "$http_code" -ne 200 ]]; then echo "$package_url is NOT a valid link.  Exiting..."; exit 1; fi
echo "OVS_SELINUX_$fdp_release_short"_RHEL10=${package_url} >> $new_package_list_file

for i in $errata_list; do
	$script_directory/get_errata_packages.sh -e $i
	package_url=$(grep packages $package_list_file | egrep -v '\-devel|ipsec|python|debug|test|scripts|central|host')
	
	if [[ $(basename $package_url | grep openvswitch | grep -v selinux) ]]; then
		package_type="OVS"
	elif [[ $(basename $package_url | grep ovn) ]]; then
		package_type="OVN"
	fi
	
	if [[ "$package_type" == "OVS" ]]; then
		package_url=$(grep packages $package_list_file | egrep -v '\-devel|ipsec|python|debug|test|scripts')
		python_package_url=$(grep packages $package_list_file | grep python | egrep -v 'debug')
		tcpdump_package_url=$(grep packages $package_list_file | grep 'noarch')
		position_b=$(basename $package_url | awk -F - '{print $2}' | awk -F '.' '{print $1$2}')
		position_b=$(echo $position_b"0")
		url_rhel_ver=$(basename $package_url | awk -F 'el' '{print $2}' | awk -F 'fdp' '{print $1}')
		echo "$package_type""$position_b"_"$fdp_release_short"_RHEL"$url_rhel_ver"=${package_url} >> $new_package_list_file
		echo "$package_type""$position_b"_PYTHON_"$fdp_release_short"_RHEL"$url_rhel_ver"=${python_package_url} >> $new_package_list_file
		echo "$package_type""$position_b"_TCPDUMP_"$fdp_release_short"_RHEL"$url_rhel_ver"=${tcpdump_package_url} >> $new_package_list_file
	elif [[ "$package_type" == "OVN" ]]; then
		ovn_common_package_url=$(grep packages $package_list_file | egrep -v '\-devel|central|host|vtep|debug')
		ovn_central_package_url=$(grep packages $package_list_file | grep central | egrep -v '\-devel|debug')
		ovn_host_package_url=$(grep packages $package_list_file | grep host | egrep -v '\-devel|debug')
		position_b=$(basename $ovn_common_package_url | awk -F - '{print $2}' | awk -F '.' '{print $1$2}')
		url_rhel_ver=$(basename $ovn_common_package_url | awk -F 'el' '{print $2}' | awk -F 'fdp' '{print $1}')
		echo "$package_type"_COMMON_"$position_b"_"$fdp_release_short"_RHEL"$url_rhel_ver"=${ovn_common_package_url} >> $new_package_list_file
		echo "$package_type"_CENTRAL_"$position_b"_"$fdp_release_short"_RHEL"$url_rhel_ver"=${ovn_central_package_url} >> $new_package_list_file
		echo "$package_type"_HOST_"$position_b"_"$fdp_release_short"_RHEL"$url_rhel_ver"=${ovn_host_package_url} >> $new_package_list_file		
	fi
done

# Remove any existing lines in $package_file referring to $fdp_release to avoid redundancy, etc
existing_line_number=$(grep -n "$fdp_release" $package_file | awk -F ':' '{print $1}' | head -1)
if [[ $existing_line_number ]]; then
	echo "Removing existing entries for $fdp_release..."
	line_number_before=$(( existing_line_number - 1 ))
	line=$(sed -n "${line_number_before}p" $package_file)

	if [[ -z "$line" ]]; then
		sed -n -i "1,$(( line_number_before - 1 )) p; $line_number_before q" $package_file
	else
		sed -n -i "1,$(( existing_line_number - 1 )) p; $existing_line_number q" $package_file
	fi
fi

# Append entries for $fdp_release to $package_file
cat $new_package_list_file >> $package_file

# copy updated fdp_package_list.sh file to infra01
rpm -q nfs-utils || sudo dnf -y install nfs-utils
mount | grep 'netqe-infra01.knqe.eng.rdu2.dc.redhat.com:/home/www/html/share'
if [[ $? -eq 0 ]]; then
	share_dir=$(mount | grep 'netqe-infra01.knqe.eng.rdu2.dc.redhat.com:/home/www/html/share' | awk '{print $3}')
else
	mkdir ~/infra01_share/
	sudo mount netqe-infra01.knqe.eng.rdu2.dc.redhat.com:/home/www/html/share ~/infra01_share/
	wait
	share_dir=$(mount | grep 'netqe-infra01.knqe.eng.rdu2.dc.redhat.com:/home/www/html/share' | awk '{print $3}')
fi

/bin/cp -f $package_file "$share_dir"

popd &>/dev/null
popd &>/dev/null
