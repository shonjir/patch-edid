#!/usr/bin/ruby
# Create display override file to force Mac OS X to use RGB mode for Display
# see https://embdev.net/topic/284710#3027030
#
# Originally created by Andreas Schwarz
#
# modified by A. Daugherity
#   see https://gist.github.com/adaugherity/7435890
# modified by J. Silva
#   see https://github.com/shonjir/patch-edid
#
# EDID 1.4 format:
#   https://en.wikipedia.org/wiki/Extended_Display_Identification_Data#EDID_1.4_data_format

require 'base64'

data=`ioreg -l -d0 -w 0 -r -c AppleDisplay`

edids=data.scan(/IODisplayEDID.*?<([a-z0-9]+)>/i).flatten
vendorids=data.scan(/DisplayVendorID.*?([0-9]+)/i).flatten
productids=data.scan(/DisplayProductID.*?([0-9]+)/i).flatten

displays = []
edids.each_with_index do |edid, i|
    disp = { "edid_hex"=>edid, "vendorid"=>vendorids[i].to_i, "productid"=>productids[i].to_i }
    displays.push(disp)
end

# Process all displays
if displays.length > 1
    puts "Found %d displays!  You should only install the override file for the one which" % displays.length
    puts "is giving you problems.","\n"
end
displays.each do |disp|

# Translate EDID to byte array
bytes=disp["edid_hex"].scan(/../).map{|x|Integer("0x#{x}")}.flatten

# Retrieve monitor model from EDID data
monitor_name=[disp["edid_hex"].match(/000000fc00((?:(?!0a)[0-9a-f][0-9a-f]){1,13})/){|m|m[1]}.to_s].pack("H*")
if monitor_name.empty?
    monitor_name = "Display"
end

# Show some info
puts "Found display '#{monitor_name}': vendorid #{disp["vendorid"]}, productid #{disp["productid"]}"
puts "Original EDID:\n#{disp["edid_hex"]}"
puts
puts "EDID version #{bytes[18]}.#{bytes[19]}"

puts "Features:"
digital_display = (bytes[20] & (0x80))>>7
color_format = (bytes[24] & (0b11000))>>3
digital_formats = ["RGB 4:4:4", "RGB 4:4:4 + YCrCb 4:4:4", "RGB 4:4:4 + YCrCb 4:2:2", "RGB 4:4:4 + YCrCb 4:4:4 + YCrCb 4:2:2"]
analog_formats = ["Monochrome or Grayscale", "RGB Color", "Non-RGB Color", "Undefined"]
if (digital_display)
  puts "  Digital Display (#{digital_formats[color_format]})"
else
  puts "  Analog Display (#{analog_formats[color_format]})"
end
if bytes[24] & (0b10000000)
  puts "  DPMS standby"
end
if bytes[24] & (0b01000000)
  puts "  DPMS suspend"
end
if bytes[24] & (0b00100000)
  puts "  DPMS active-off"
end
if bytes[24] & (0b00000100)
  puts "  Standard sRGB color space"
end
puts "Number of extension blocks: #{bytes[126]}"

puts "Setting color support to RGB 4:4:4 only"
bytes[24] &= ~(0b11000)

# Optional - remove extension block(s)
#puts "removing extension block"
#bytes = bytes[0..127]
#bytes[126] = 0

# Recalculate EDID checksum
bytes[127] = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
puts "Recalculated checksum: 0x%x" % bytes[127]
puts
puts "New EDID:\n#{bytes.map{|b|"%02X"%b}.join}"

Dir.mkdir("DisplayVendorID-%x" % disp["vendorid"]) rescue nil
f = File.open("DisplayVendorID-%x/DisplayProductID-%x" % [disp["vendorid"], disp["productid"]], 'w')
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
  <integer>#{disp["vendorid"]}</integer>
  <key>DisplayProductID</key>
  <integer>#{disp["productid"]}</integer>
</dict>
</plist>"
f.close
puts "\n"
end   # displays.each

