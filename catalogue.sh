#!/bin/bash

source ./common.sh

app_name="catalogue"

check_root
app_setup
nodejs_setup
app_restart
total_time