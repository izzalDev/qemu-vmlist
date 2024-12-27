#!/bin/bash
qemu-system-aarch64 \
  -machine null \
  -m 1G \
  -smp 2 \
  -boot order=null \
  -drive file=./resources/storage/alphine-server2.vdi,format=vdi \
  -cdrom ./resources/iso/alpine-virt-3.21.0-aarch64.iso \
  -display cirrus \
