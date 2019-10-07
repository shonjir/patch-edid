#!/bin/sh
# Install display overrides to mounted system volume

# Source files located in script directory
scriptdir="${0%/*}"
scriptdir=$(cd "${scriptdir}";echo $PWD)
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
    "$0" backup
    echo
    echo "Installing EDID overrides to ${overrides}..."
    ;;
  link)
    "$0" backup
    echo
    echo "Linking EDID overrides to ${overrides}..."
    ;;
  show)
    echo "Listing installed EDID overrides..."
    ;;
  backup)
    echo "Backing up EDID overrides..."
    ;;
  restore)
    echo "Restoring EDID overrides from backup..."
    ;;
  *) echo "Usage: $0 [copy|link|show|backup|restore]" ; exit 1 ;;
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
      rm -f "${target}" 2>/dev/null
      cp -v "${source}" "${target}"
      ;;
    link)
      rm -f "${target}" 2>/dev/null
      ln -vs "${source#${mountpoint}}" "${target}"
      ;;
    show)
      # Similar to backup, but only shows status
      if [ -r "${target}" ]; then
        if grep -E "(EDIDPatcher| \(.*\)</string>)" "${target}" 1>/dev/null 2>/dev/null; then
          echo "${file}: target is patched"
        elif [ -r "${backup}" ]; then
          echo "${file}: backup exists"
        else
          echo "${file}: target is not patched"
        fi
      else
        echo "${file}: target does not exist"
      fi
      ;;
    backup)
      if [ -r "${target}" ]; then
        if grep -E "(EDIDPatcher| \(.*\)</string>)" "${target}" 1>/dev/null 2>/dev/null; then
          echo "${file}: target patched, skipping backup"
        elif [ -r "${backup}" ]; then
          echo "${file}: backup exists, nothing to do"
        else
          mv -vf "${target}" "${backup}"
        fi
      else
        echo "${file}: not found, nothing to do"
      fi
      ;;
    restore)
      if [ -r "${backup}" ]; then
        mv -vf "${backup}" "${target}"
      else
        # assumes that there was no original target
        echo "${file}: backup not found, removing target"
        rm -vf "${target}"
        # Try removing empty source directory
        rmdir "${sourcedir}"
      fi
      ;;
  esac
done

