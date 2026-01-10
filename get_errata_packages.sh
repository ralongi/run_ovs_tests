#! /bin/bash

# Script to obtain URLs for FDP related packages based on errata ID(s) and optional arch provided (default arch is x86_64)
# You must have an active kerberos ticket for this script to work

$dbg_flag
package_list_file=~/package_list.txt

rm -f $package_list_file

usage() { echo "$0 usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }

[ $# -eq 0 ] && usage
while getopts "he:f:a:" arg; do
  case $arg in
    e) # Specify an errata ID. Example: -e 111078
      errata=${OPTARG}
      ;;
    f) # Specify a file containing errata IDs. Example: -f errata_list.txt 
      errata_list_file=${OPTARG}
      ;;
    a) # Specify an arch (default is x86_64). Example: -a aarch64
      arch=${OPTARG}
      ;;
    h) # Display help
      usage
      ;;
  esac
done

if [[ $errata ]] && [[ $errata_list_file ]]; then
	echo ""
	echo "  Please specify either -e <single errata ID> OR -f <errata list file>."
	echo "  The -e option is used for a single errata; the -f option is used for multiple erratas."
	echo "  The -e and -f options should NOT be used simultaneously."
	echo ""
	exit 1
fi

if [[ $errata_list_file ]]; then
	errata_list=$(cat $errata_list_file)
elif [[ $errata ]]; then
	errata_list=$errata
fi

if [[ -z $arch ]]; then arch="x86_64"; fi

rm -f $package_list_file

# Errata packages

echo "Errata Packages:" >> $package_list_file

for i in $errata_list; do
	echo "" >> $package_list_file
	echo "#########################################################################" >> $package_list_file
	echo "" >> $package_list_file
	echo "Errata: https://errata.devel.redhat.com/advisory/$i" >> $package_list_file
	echo "Package List:" >> $package_list_file

	curl -su : --negotiate https://errata.devel.redhat.com/api/v1/erratum/$i/builds | jq > ~/builds.txt
	build_id=$(grep "id" ~/builds.txt | awk '{print $NF}' | tr -d ,)
	curl -su : --negotiate https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=$build_id > ~/builds2.txt
	if [[ ! $(grep $arch.rpm ~/builds2.txt) ]]; then
		echo "" >> $package_list_file		
		echo "It appears that the $arch arch is not available" >> $package_list_file
	else
		echo "" >> $package_list_file
		grep $arch.rpm ~/builds2.txt | awk -F '"' '{print $4}' >> $package_list_file
		grep noarch.rpm ~/builds2.txt | awk -F '"' '{print $4}' >> $package_list_file
	fi
 	rm -f ~/builds.txt ~/builds2.txt
done

echo ""
cat $package_list_file
