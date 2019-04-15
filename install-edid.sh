#!/bin/sh
# Install display overrides to all mounted system volumes

case "$1" in
  copy|link) ;;
  *) echo "Usage: $0 [copy|link]" ; exit 1 ;;
esac

find /Volumes -type d -mindepth 1 -maxdepth 1 | while read mountpoint
do
  echo "Checking ${mountpoint}..."

  overrides="${mountpoint}/System/Library/Displays/Contents/Resources/Overrides/"
  if [ -d "${overrides}" ]; then
    echo "Installing EDID overrides to ${overrides}..."
    src=$(pwd)
    find DisplayVendorID-* -type f | while read line
    do
      mkdir -p "${overrides}${line%/*}"
      rm -f "${overrides}${line}"
      case "$1" in
      copy) cp -vf "${src}/${line}" "${overrides}${line}" ;;
      link) ln -vsf "${src##${mountpoint}}/${line}" "${overrides}${line}" ;;
      esac
    done
  else
    echo "${mountpoint}: Not a system volume!"
  fi
done

