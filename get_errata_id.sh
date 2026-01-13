#! /bin/bash

# Script to obtain/report errata IDs based on FDP release name provided

dbg_flag=${dbg_flag:-"set +x"}
$dbg_flag
fdp_release=$1
if [[ $# -lt 1 ]]; then echo "Please provide FDP release designation:"; read fdp_release; fi
echo "FDP Release: $fdp_release"

if [[ -z "$errata_list" ]]; then
	rm -f ./batches.txt && touch ./batches.txt
	if [[ $(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" | grep batches) ]]; then
		batches=$(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" | awk -F '"' '{print $4}' | awk -F '/' '{print $NF}' | sort -u)
		for i in $batches; do
			curl -su : --negotiate https://errata.devel.redhat.com/api/v1/batches/$i | jq | grep id | awk '{print $NF}' | grep -v , >> ./batches.txt
		done
		errata_list=$(cat ./batches.txt)
	elif [[ $(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" | grep advisory) ]]; then
		count=$(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" | grep advisory | wc -l)
		while [[ $count -gt 0 ]]; do
			errata_id=$(curl -su : --negotiate https://errata.devel.redhat.com/advisory/filters/4400 | grep "$fdp_release" | grep advisory | tail -$count | head -1 | awk -F 'advisory' '{print $NF}' | awk -F '"' '{print $1}' | tr -d /)
			errata_list+=" $errata_id"		
			let count--
		done
	fi
fi

if [[ $errata_list ]]; then
	echo "Errata list for FDP release $fdp_release: $(echo $errata_list)"
else
	echo "No erratas match the query for $fdp_release.  Please confirm that $fdp_release is correct."
fi
