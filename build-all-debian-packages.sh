#!/bin/bash

set -e

./build-debian-packages.sh raspbian-jessie
./build-debian-packages.sh debian-jessie
./build-debian-packages.sh raspbian-buster
./build-debian-packages.sh debian-buster
