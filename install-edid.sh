#!/bin/sh
# Install display overrides to all mounted system volumes

find /Volumes -type d -mindepth 1 -maxdepth 1 | while read mountpoint
do
  echo "Checking ${mountpoint}..."

  overrides="${mountpoint}/System/Library/Displays/Contents/Resources/Overrides/"
  if [ -d "${overrides}" ]; then
    echo "Installing EDID overrides to ${overrides}..."
    #cp -rv DisplayVendorID-* "${overrides}"
    dir=$(pwd)
    dir="${dir##${mountpoint}}"
    find DisplayVendorID-* -type f | while read line
    do
      ln -vsf "${dir}/${line}" "${overrides}${line}"
    done
  else
    echo "${mountpoint}: Not a system volume!"
  fi
done

