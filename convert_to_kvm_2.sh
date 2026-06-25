#!/usr/bin/env bash

container_name="$1"
working_dir="$container_name"
cache_dir="/mnt/kvm_conversions_cache"

mkdir $working_dir
mkdir ${cache_dir}/${container_name}


#incus export ${container_name} ${working_dir}/${container_name}.tar  --instance-only --compression none
#tar xf ${working_dir}/${container_name}.tar -C ${working_dir}/
#rm  ${working_dir}/${container_name}.tar

incus stop ${container_name}
incus config set ${container_name} security.privileged=true
incus start ${container_name}
incus stop ${container_name}
incus config unset ${container_name} security.privileged
incus start ${container_name}
incus stop ${container_name}


zfs set mountpoint=/mnt/dataset_mounts/${container_name} lxd/containers/${container_name}
zfs mount lxd/containers/${container_name}

# Define the target rootfs path for clarity
rootfs_path="/mnt/dataset_mounts/${container_name}/rootfs"

# ==============================================================================
# CRITICAL CLEANUP: Sanitize cloud-init state and logs before packaging
# ==============================================================================
echo "==> Purging legacy cloud-init runtime cache and instance tracking..."
rm -rf "${rootfs_path}"/var/lib/cloud/*

echo "==> Clearing historical cloud-init logs to prevent log pollution..."
rm -f  "${rootfs_path}"/var/log/cloud-init*


time distrobuilder \
    pack-incus ubuntu.yaml /mnt/dataset_mounts/${container_name}/rootfs ${working_dir} --cache-dir ${cache_dir}/${container_name} \
    -o image.variant=cloud \
    -o image.architecture=amd64 \
    -o image.release=jammy \
    -o targets.incus.vm.size=$(( 12 * 1024 *1024 * 1024 )) \
    --compression=none \
    --type=unified \
    --vm \
    --disable-overlay

zfs umount lxd/containers/${container_name}
zfs set mountpoint=legacy lxd/containers/${container_name}

incus image import ${working_dir}/*.tar --alias ${container_name}
rm -r ${working_dir}
