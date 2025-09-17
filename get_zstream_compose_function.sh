get_zstream_compose()
{
    $dbg_flag

	if [[ $# -lt 1 ]]; then
		echo "Please provide a RHEL version"
		echo "Example: $0 8.6"
		exit 0
	fi

	zstream_raw=$1
	arch=$2
	if [[ $# -lt 2 ]]; then arch="x86_64"; fi
	yaml_file=~/ZConfig.yaml

	get_zstream_kernel_info()
	{
		$dbg_flag
		
		file_location1=${file_location1:-"tail -n1"}
		file_location2=${file_location2:-""}
		
		if [[ ${z_stream_base::1} -lt 8 ]]; then
			variant=server
		else
			variant=baseos
		fi

		if [[ $(grep $z_stream_base $yaml_file | grep -E -v 'x86_64') ]]; then
			kernel=$(grep $z_stream_base -A30 $yaml_file | grep -E -v 'x86_64' | grep version -A1 | grep kernel | grep -v rt | tr -d " ")
			if [[ ${z_stream_base::1} -lt 8 ]]; then
				z_stream_repo_url=$(grep -A35 -w "$z_stream_base" $yaml_file | grep "$arch" | grep -i $variant | awk '{print $2}' | tr -d "'")
			else	
				z_stream_repo_url=$(grep -A35 -w "$z_stream_base" $yaml_file | grep "$arch" | grep -i $variant | awk '{print $3}' | head -n1)
			fi
			
			if [[ $(echo $z_stream_repo_url | awk '{print substr($0,length($0),1)}') != "/" ]]; then
			    z_stream_repo_url=$z_stream_repo_url"/"
			fi

		    if [[ $file_location2 ]]; then
		        zstream_kernel=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | $file_location2 | awk -F 'href=' '{print $2}' | awk -F '"' '{print $2}' | awk -F ".$arch" '{print $1}')
		        zstream_kernel_rpm=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | $file_location2 | awk -F 'href=' '{print $2}' | awk -F '"' '{print $2}')
			    zstream_kernel_date=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | $file_location2 | awk -F 'href=' '{print $2}' | awk -F '"right">' '{print $2}' | awk '{print $1}')
			else
			    zstream_kernel=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | awk -F 'href=' '{print $2}' | awk -F '"' '{print $2}' | awk -F ".$arch" '{print $1}')
			    zstream_kernel_rpm=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | awk -F 'href=' '{print $2}' | awk -F '"' '{print $2}')
			zstream_kernel_date=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | $file_location1 | awk -F 'href=' '{print $2}' | awk -F '"right">' '{print $2}' | awk '{print $1}')
			fi
			
			zstream_kernel_core_rpm=$(echo $zstream_kernel_rpm | sed s/kernel/kernel-core/g)
			zstream_kernel_modules_rpm=$(echo $zstream_kernel_rpm | sed s/kernel/kernel-modules/g)        
		fi 
	}

	get_kernel_from_compose()
	{
		dbg_flag=${dbg_flag:-"set +x"}
		$dbg_flag

		# to obtain the kernel package contained in a given compose
		compose_id=$1

		if [[ $(echo $compose_id | awk -F "." '{print $1}' | awk -F "-" '{print $NF}') -ge 8 ]]; then
			variant="BaseOS"
		else
			variant="Server"
		fi

		distro_id=$(bkr distro-trees-list --name=$compose_id --arch=$arch | grep -B2 "Variant: $variant" | grep ID | awk '{print $NF}')
		if [[ -z $distro_id ]]; then return 1; fi

		build_url=$(curl -sL https://beaker.engineering.redhat.com/distrotrees/$distro_id#lab-controllers | grep -A12 rdu.redhat.com | grep http | grep -v href | tr -d " " | sort -u)

		kernel_id=$(curl -sL "$build_url"Packages | grep -E 'kernel-[0-9]' | head -n1 | awk '{print $6}' | awk -F '"' '{print $2}')
		kernel_id_short=$(echo $kernel_id | awk -F ".$arch" '{print $1}')
	}

	get_zstream_compose()
	{
		tmp0=$(mktemp)
		
		if [[ -z $zstream_date_integer ]]; then
			zstream_date_integer=$(echo $zstream_kernel_date | tr -d '-' | bc)
		fi
		
		curl -sL https://beaker.engineering.redhat.com/distros/?simplesearch=rhel-$zstream_raw | grep RHEL | grep view | grep -E -v '\.d|\.n|\.t' > $tmp0
		
		latest_date_integer=$(head -n1 $tmp0 | cut -d- -f4 | cut -d. -f1)
		line_num=$(grep -n $zstream_date_integer -m1 $tmp0 | cut -d: -f1)
		while [[ ! $line_num ]] && [[ $zstream_date_integer -le $latest_date_integer ]]; do
		    let zstream_date_integer++
		    line_num=$(grep -n $zstream_date_integer -m1 $tmp0 | cut -d: -f1)
		done
		orig_line_num=$line_num

		while [[ $line_num -ge 1 ]]; do
		    target_compose=$(sed -n "$line_num"p $tmp0 | cut -d\> -f2 | cut -d\< -f1)
		    get_kernel_from_compose $target_compose
		    if [[ $(echo $kernel_id | awk -F ".$arch" '{print $1}') == $zstream_kernel ]]; then
		        echo "Compose $target_compose contains $zstream_kernel"
		        zstream_compose=$target_compose
		        break
		    else
		        echo "Compose $target_compose does not contain $zstream_kernel.  Still checking..."
		        echo ""
		    fi
		    let line_num--
		done

		if [[ $line_num -eq 0 ]]; then
		    echo "The $orig_line_num available stable RHEL-$zstream_raw composes in Beaker that could potentially contain the necessary Z stream kernel were checked but it appears that none currently contain $zstream_kernel."
		    echo ""
		    echo "It is possible/likely that $zstream_kernel will be added to a future RHEL-$zstream_raw compose so you should check again in the future."
		    echo ""
		fi
	}

	echo ""
	echo "Gathering information on the current Z stream kernel and compose for RHEL-$1 ($arch)..."

	if [[ $(echo $1 | grep RHEL) ]]; then
		z_stream_base=$(echo $1 | awk -F '-' '{print $2}' | tr -d . | cut -c-2)
	else
		z_stream_base=$(echo $1 | tr -d . | cut -c-2)
	fi
	z_stream_base=$(echo $z_stream_base)z

	wget -q -O $yaml_file https://gitlab.cee.redhat.com/kernel-qe/core-kernel/kernel-general/-/raw/master/Sustaining/ZConfig.yaml

	get_zstream_kernel_info

	zstream_kernel_length=$(echo $zstream_kernel | awk -F '-' '{print $NF}' | awk -F '.' '{print NF}')
	if [[ $zstream_kernel_length -le 3 ]]; then
		file_location1="tail -n2"
		file_location2="head -n1"
		get_zstream_kernel_info
	fi

	if [[ $zstream_kernel ]]; then
		echo "The current RHEL-$zstream_raw Z stream kernel has been identified to be $zstream_kernel dated $zstream_kernel_date."
	fi

	kernel_major_ver=$(echo $zstream_kernel | cut -d- -f2)
	kernel_minor_ver=$(echo $zstream_kernel | cut -d- -f3)
	zstream_kernel_url=http://download.devel.redhat.com/brewroot/packages/kernel/$kernel_major_ver/$kernel_minor_ver/$arch/

	http_code=$(curl --silent --head --write-out '%{http_code}' "$zstream_kernel_url" | grep HTTP | awk '{print $2}')
	if [[ "$http_code" -eq 200 ]]; then good_kernel_url="yes"; fi

	echo "Searching for a valid compose to use for RHEL-$zstream_raw Z stream..."

	if [[ $zstream_kernel ]]; then
		f=$(echo $zstream_kernel | awk -F'.' '{print $NF}')
		zstream_kernel_tmp=$(echo $zstream_kernel | sed "s/.$f//") 
		
		if [[ "$zstream_kernel_tmp" == "$kernel" ]]; then
			zstream_kernel=$(curl -sL "$z_stream_repo_url"/Packages/k/ | grep $kernel | tail -n2 | head -n1 | awk -F 'href=' '{print $2}' | awk -F '"' '{print $2}' | awk -F ".$arch" '{print $1}')
			zstream_kernel_date=$(curl -sL "$z_stream_repo_url"Packages/k/ | grep $kernel | tail -n2 | head -n1 | awk -F 'href=' '{print $2}' | awk -F '"right">' '{print $2}' | awk '{print $1}')
		fi

		get_zstream_compose 

	else
		echo ""
		echo "There is no Z stream kernel currently available for RHEL-$zstream_raw for $arch"
		exit 0
	fi
}
