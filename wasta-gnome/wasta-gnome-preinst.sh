#!/bin/bash

# Auto-select current display-manager to keep.
DM=$(systemctl show display-manager.service | grep Id= | awk -F= '{print $2}')
echo "gdm3	shared/default-x-display-manager	select	$DM" |\
	debconf-set-selections
echo "gdm3	shared/default-x-display-manager seen" |\
	debconf-set-selections
