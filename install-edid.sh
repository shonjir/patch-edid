#!/bin/sh
# Install display overrides to mounted system volume

# Source files located in script directory
scriptdir=$(cd $(dirname $0);echo $PWD)
mountpoint=
# scriptdir contains mountpoint when run from recovery
case "${scriptdir}" in
  /Volumes/*)
    base="${scriptdir#/Volumes/*/}"
    mountpoint="${scriptdir%/${base}}"
    ;;
esac

# Check overrides path
overrides="${mountpoint}/System/Library/Displays/Contents/Resources/Overrides"
if [ ! -d "${overrides}" ]; then
  if [ "${mountpoint}" ]; then
    echo "${mountpoint}: Not a system volume!"
  else
    echo "Not a system volume!"
  fi
  exit 1
fi

case "$1" in
  copy)
    $0 backup
    echo
    echo "Installing EDID overrides to ${overrides}..."
    ;;
  link)
    $0 backup
    echo
    echo "Linking EDID overrides to ${overrides}..."
    ;;
  backup)
    echo "Backing up EDID overrides..."
    ;;
  restore)
    echo "Restoring EDID overrides from backup..."
    ;;
  *) echo "Usage: $0 [copy|link|backup|restore]" ; exit 1 ;;
esac

# Try installing overrides...
find "${scriptdir}"/DisplayVendorID-* -type f | while read -r source
do
  sourcedir="${source%/*}"
  file="${source#${scriptdir}/}"
  target="${overrides}/${file}"
  backup="${overrides}/${file}.backup"

  mkdir -p "${sourcedir}"

  case "$1" in
    copy)
      rm -vf "${target}"
      cp -v "${source}" "${target}"
      ;;
    link)
      rm -vf "${target}"
      ln -vs "${source#${mountpoint}}" "${target}"
      ;;
    backup)
      if [ -r "${target}" ]; then
        if grep -E "(EDIDPatchOption| \(.*\)</string>)" "${target}" 1>/dev/null 2>/dev/null; then
          echo "${file}: target patched, skipping backup"
        elif [ -r "${backup}" ]; then
          echo "${file}: backup exists, nothing to do"
        else
          mv -vf "${target}" "${backup}"
        fi
      fi
      ;;
    restore)
      if [ -r "${backup}" ]; then
        mv -vf "${backup}" "${target}"
      else
        echo "${file}: backup not found, nothing to do"
      fi
      ;;
  esac
done

