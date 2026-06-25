#!/usr/bin/env bash

# ===================== #
# PER INSTANCE SETTINGS #

BASE_OS=ubuntu
OS_VER=noble
VM_SIZE=8

# ===================== #
#   Conversion script   #

# Variables for conversion
container_name="$1"
working_dir="$container_name"
cache_dir="/mnt/kvm_conversions_cache"

# Cache and work directory setup
echo "====> Creating temporary work directories..."
mkdir $working_dir
mkdir ${cache_dir}/${container_name}

#incus export ${container_name} ${working_dir}/${container_name}.tar  --instance-only --compression none
#tar xf ${working_dir}/${container_name}.tar -C ${working_dir}/
#rm  ${working_dir}/${container_name}.tar

# Proper cleaning up of cloud-init state
echo "====> Cleaning cloud-init state..."
incus start ${container_name}
incus exec ${container_name} -- /bin/bash -c "cloud-init clean --logs"

# Ensure proper privilege setup
echo "====> Setting proper privilege..."
incus stop ${container_name}
incus config set ${container_name} security.privileged=true
incus start ${container_name}
incus stop ${container_name}
incus config unset ${container_name} security.privileged
incus start ${container_name}
incus stop ${container_name}

# Setting mountpoints for data acces
echo "====> Mounting container volume..."
zfs set mountpoint=/mnt/dataset_mounts/${container_name} lxd/containers/${container_name}
zfs mount lxd/containers/${container_name}

# Starting the image building
echo "====> Starting distrobuilder..."
time distrobuilder \
    pack-incus ${BASE_OS}.yaml /mnt/dataset_mounts/${container_name}/rootfs ${working_dir} --cache-dir ${cache_dir}/${container_name} \
    -o image.variant=cloud \
    -o image.architecture=amd64 \
    -o image.release=${OS_VER} \
    -o targets.incus.vm.size=$(( (${VM_SIZE} + 4) * 1024 * 1024 * 1024)) \
    --compression=none \
    --type=unified \
    --vm \
    --disable-overlay

# Releasing the mounted volume
echo "====> Unmounting container volume..."
zfs umount lxd/containers/${container_name}
zfs set mountpoint=legacy lxd/containers/${container_name}

# Import the new image to Incus
echo "====> Importing the created image..."
incus image import ${working_dir}/*.tar --alias ${container_name}

# Removing temporary working directories
echo "====> Removing temporary directories..."
rm -r ${working_dir}
