#!/bin/bash

## SHM Node Debugging script. This is scheduled to run as a cron job every half hour, but also
## designed to be run manually for debugging purposes. Output human readable - for automated
## checks and commands, see the node-debugging folder containing directory tree to build
## an ipk file to install on node (tested on Angstrom) along with 2 ansible-playbooks
## used to execute the scripts

## It serves the following features
## 1: checks for running processes
## 2: Checks for the 2 different sensor errors we have been seeing
## 3: Assesses STP stability based on frequency of STP related messages in the logs
## 4: Checks to see if the node is currently in process of training ML, and if so shows
## the percentage completed.
## 5: Checks to see if both persistent and volatile storage are full

## Software Version
_version=`opkg list-installed shm`

## Path to pgrep binary
_pgrep="/usr/bin/pgrep"

## Add binary list here
_chklist="/usr/bin/ntpd /sbin/dp-event /sbin/dp-ml /sbin/df-dynevent /sbin/dp-heuro /sbin/da /sbin/ns /sbin/dp-raw"

## Get node ID
_nodeid=`hostname`

## Get node ip addr
_ipAddr=$(ip addr show br0 | grep "inet\ " | sed 's/[A-Za-z]*//g' | sed 's/\/.*//g')

## Convert uptime to nice format
_uptime=$(/usr/bin/uptime | /usr/bin/awk -F'( |,|:)+' '{print $6,$7",",$8,"hours,",$9,"minutes."}')

## Do not change below
_failed="false"
_service="Service:"

## Nice little function found on NIXCraft
_running() {
  local p="${1##*/}"
  local s="true"
  $_pgrep "${p}" >/dev/null || { s="false"; _failed="true"; _service="${_service} $1,"; }
  [[ "$s" == "true" ]] && echo "$1 running" || { echo -n "$1 NOT running"; [[ ! -f "$1" ]] && echo " [ $1 NOT found ]" || echo ; }
}

_sensErrs() {
  _err1="ERR Accelerometer: Not initialized"
  _err2="omap_i2c omap_i2c.3: controller timed out"

  _check1=$(cat /var/log/omf_rc* | grep "$_err1")
  res=$(echo "$_check1" | wc -l)
  if [[ "$_check1" == "" ]]; then
    echo "Sensor Error Type 1 (aka Red Light Error) not found"
  else
    echo "Sensor Error Type 1 (aka Red Light Error) FOUND"
    echo "_$err1 present in omf_rc.log: Number of errors found == $res"
  fi
  _check2=$(cat /var/log/kern* | grep "$_err2")

  res=$(echo "$_check2" | wc -l)

  if [[ "$_check2" == "" ]]; then
    echo "Sensor Error Type 2 (aka I2C Timeouts) not found"
  elif [ "$res" -gt 5 ]; then
    echo "Sensor Error Type 2 (aka I2C Timeouts) FOUND"
    echo "$_err2 present in kern.log: Number of errors found == $res"
  elif [ "$res" -gt 0 -a "$res" -lt 5 ]; then
    echo "WARN: Sensor Error Type 2 (aka I2C Timeouts) found in low numbers"
  fi
}

_stpErrs()
{
  _stpErr=$(cat /var/log/kern* | grep 'br0: topology change detected\|with own address as source address')

  res=$(echo "$_stpErr" | wc -l)
  _thresh1="15"
  _thresh2="50"

  if [ "$res" -lt "$_thresh1" ]; then
    echo "Network stability appears normal"
  elif [ "$res" -gt "$_thresh1" -a "$res" -lt "$_thresh2" ]; then
    echo "Possible STP instability"
    echo "'br0: topology change detected' errors present in kern.log: Number of errors found == $res"
  elif
    [ "$res" -gt "$_thresh2" ]; then
    echo "Significant STP instability"
    echo "'br0: topology change detected' errors present in kern.log: Number of errors found == $res"
  fi
}

_chkTraining()
{
  _path="/home/root/ml_sensor_*"

  for file in $_path; do
    if test -e "$file"; then
      echo "ML Training Complete"
      break
    else
      echo "ML Training In Progress"
      for file in /home/root/ml_training*; do
        _samples=`/bin/cat "$file" | wc -l`
        _complete="3000"
        _per=$((100*$_samples/$_complete))
        echo "$file: $_samples out of 3000 samples ($_per% Complete)"
      done
    fi
  done
}

_chkFS()
{
  _volFS=$(/bin/df -h /var/volatile | /usr/bin/tail -1 | awk '{ print $5 }')
  _perFS=$(/bin/df -h /media/mmcblk0p2 | /usr/bin/tail -1 | awk '{ print $5 }')

  if [ "$_volFS" == "100%" ]; then
    echo "Volatile Storage Full - Remove old logs or reboot"
  elif [ "$_perFS" == "100%" ]; then
    echo 'Persistant Storage\SD Card full'
  fi
  res=$(echo $_volFS | sed 's/%//g')
  if [ "$res" -gt 90 ]; then
    echo "WARN: Voltatile Storage is almost full"
  else
    echo "Storage issues not found"
  fi
}

_checkPatch()
{
  _blockPath='/home/root/patches/BLOCK'
  for file in /home/root/patches/*.patch; do
    if test -e "$_blockPath"; then
      break
    fi
    res=$(echo $file |  sed 's/_.*//' | sed 's/.*\///g')
    if [ "$res" == "$_nodeid" ]; then
      echo "Patch file for this node found in directory in absence of BLOCK file"
    fi
  done
}


## header
echo "SHM Node Service Status on $_nodeid @ $(date)"
echo "---------------------------------------------------------------------"
## Check if your service is running or not
for s in $_chklist; do
  _running "$s"
done

echo -e "\nSHM Node Debugging Info:"
echo -e "\nGeneral Info: -------------------------------------------------------"
echo -e "\n$_uptime since last boot"
echo -e "\nNode software is $_version"
  _checkPatch

echo -e "\nSensor Status: ------------------------------------------------------"
  _sensErrs

echo -e "\nNetwork Stability: ---------------------------------------------"
  _stpErrs

echo -e "\nML Training Status: --------------------------------------------"
  _chkTraining

echo -e "\nStorage Status: ------------------------------------------------"
  _chkFS

