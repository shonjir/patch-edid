#!/usr/bin/ruby
# Create display override file to force Mac OS X to use RGB mode for Display
# see http://embdev.net/topic/284710

require 'base64'

data=`ioreg -l -d0 -w 0 -r -c AppleDisplay`

edid_hex=data.match(/IODisplayEDID.*?<([a-z0-9]+)>/i)[1]
vendorid=data.match(/DisplayVendorID.*?([0-9]+)/i)[1].to_i
productid=data.match(/DisplayProductID.*?([0-9]+)/i)[1].to_i
# Retrieve monitor model from EDID data
monitor_name=[edid_hex.match(/000000fc00(.*?)0a/){|m|m[1]}].pack("H*")
if monitor_name.empty?
    monitor_name = "Display"
end

puts "found display '#{monitor_name}': vendorid #{vendorid}, productid #{productid}, EDID:\n#{edid_hex}"

bytes=edid_hex.scan(/../).map{|x|Integer("0x#{x}")}.flatten

puts "Setting color support to RGB 4:4:4 only"
bytes[24] &= ~(0b11000)

puts "Number of extension blocks: #{bytes[126]}"
puts "removing extension block"
bytes = bytes[0..127]
bytes[126] = 0

bytes[127] = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
puts
puts "Recalculated checksum: 0x%x" % bytes[127]
puts "new EDID:\n#{bytes.map{|b|"%02X"%b}.join}"

Dir.mkdir("DisplayVendorID-%x" % vendorid) rescue nil
f = File.open("DisplayVendorID-%x/DisplayProductID-%x" % [vendorid, productid], 'w')
f.write '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">'
f.write "
<dict>
  <key>DisplayProductName</key>
  <string>#{monitor_name} - forced RGB mode (EDID override)</string>
  <key>IODisplayEDID</key>
  <data>#{Base64.encode64(bytes.pack('C*'))}</data>
  <key>DisplayVendorID</key>
  <integer>#{vendorid}</integer>
  <key>DisplayProductID</key>
  <integer>#{productid}</integer>
</dict>
</plist>"
f.close
