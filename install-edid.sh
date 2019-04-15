#!/bin/sh
# Install display overrides to all mounted system volumes

case "$1" in
  link|test) LINK="ln -vsf" ;;
  *)    COPY="cp -vf" ;;
esac

find /Volumes -type d -mindepth 1 -maxdepth 1 | while read mountpoint
do
  echo "Checking ${mountpoint}..."

  overrides="${mountpoint}/System/Library/Displays/Contents/Resources/Overrides/"
  if [ -d "${overrides}" ]; then
    echo "Installing EDID overrides to ${overrides}..."
    src=$(pwd)
    src="${src##${mountpoint}}"
    find DisplayVendorID-* -type f | while read line
    do
      mkdir -p "${overrides}${line%/*}"
      ${COPY} "${src}/${line}" "${overrides}${line}"
    done
  else
    echo "${mountpoint}: Not a system volume!"
  fi
done

