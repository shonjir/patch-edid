#!/bin/sh

DECODER=`which edid-decode 2>/dev/null`

IOREG() {
  ioreg -l -d0 -w 0 -r -c AppleDisplay
}

if [ "${DECODER}" ]; then
  IOREG \
  |grep IODisplayEDID \
  |sed -e 's,.*<\(.*\)>,\1,' \
  |while read edid
  do
    echo $edid | edid-decode
  done
else
  IOREG
fi

