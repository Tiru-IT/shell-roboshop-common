#!/bin/bash
source ./common.sh

app_name="shipping"

check_root
app_setup
java_setup
systemd_setup
clint_mysql
app_restart
total_time