#!/bin/sh

ioreg -l -d0 -w 0 -r -c AppleDisplay \
  | grep IODisplayEDID \
  | sed -e 's,.*<\(.*\)>,\1,' \
  | while read edid
do
  echo $edid | edid-decode
done

