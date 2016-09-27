#!/bin/bash

set -e

./build-debian-packages.sh raspbian-jessie
./build-debian-packages.sh raspbian-wheezy
./build-debian-packages.sh debian-jessie
