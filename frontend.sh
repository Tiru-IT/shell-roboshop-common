#!/bin/bash

source ./common.sh

check_root
nginx_setup
systemd_setup
app_restart
total_time