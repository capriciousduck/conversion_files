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


time distrobuilder \
    pack-incus centos.yaml /mnt/dataset_mounts/${container_name}/rootfs ${working_dir} --cache-dir ${cache_dir}/${container_name} \
    -o image.variant=cloud \
    -o image.architecture=amd64 \
    -o image.release=9-Stream \
    -o targets.incus.vm.size=5368709120 \
    --compression=none \
    --type=unified \
    --vm \
    --disable-overlay

zfs umount lxd/containers/${container_name}
zfs set mountpoint=legacy lxd/containers/${container_name}

incus image import ${working_dir}/*.tar --alias ${container_name}
rm -r ${working_dir}
