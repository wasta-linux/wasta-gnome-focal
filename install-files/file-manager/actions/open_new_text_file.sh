#!/bin/bash

if [[ ! -d $1 ]]; then
    exit 1
fi
base_dir = $1
gedit "$base_dir/new file"
