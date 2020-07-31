#!/bin/bash

name="new file"
if [[ $LANGUAGE == 'fr_FR' ]]; then
    name="nouveau fichier"
fi
gedit "$1/$name"
