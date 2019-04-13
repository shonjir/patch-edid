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

# Show diff between two strings
def diff( s1, s2 )
  t = s1.chars
  return s2.chars.map{|c| c == t.shift ? '-' : c}.join
end

# Decode EDID block
def decode_edid( bytes )
  puts "  EDID version #{bytes[18]}.#{bytes[19]}"
  # color format in byte 24, bits 4-3
  color_format = (bytes[24] & (0b11000))>>3
  # Display type in byte 20, bit 7
  if (bytes[20] & (0x80))>>7
    formats = ["RGB 4:4:4", "RGB 4:4:4 + YCrCb 4:4:4", "RGB 4:4:4 + YCrCb 4:2:2", "RGB 4:4:4 + YCrCb 4:4:4 + YCrCb 4:2:2"]
    display_type = "Digital"
  else
    formats = ["Monochrome or Grayscale", "RGB Color", "Non-RGB Color", "Undefined"]
    display_type = "Analog"
  end
  puts "  #{display_type} input (#{formats[color_format]})"
  # dpms features in byte 24, bits 7-5
  if bytes[24] & (0b11100000)
    dpms = []
    if bytes[24] & (0b10000000)
      dpms.push("standby")
    end
    if bytes[24] & (0b01000000)
      dpms.push("suspend")
    end
    if bytes[24] & (0b00100000)
      dpms.push("active-off")
    end
    puts "  DPMS features: #{dpms.join(', ')}"
  end
  # Color space in byte 24, bit 2
  if bytes[24] & (0b00000100)
    puts "  Standard sRGB color space"
  end
  if bytes[24] & (0b10)
    puts "  Preferred timing mode specified"
  end
  if bytes[24] & (0b1)
    puts "  Continuous timings with GTF or CVT"
  end
  # Extension blocks are 17 bytes in length beginning at byte 128
  extension_blocks = bytes[126]
  if extension_blocks
    puts "  Extension blocks: #{extension_blocks}"
    for index in (0..(extension_blocks-1))
      offset = 128 + index * 18
      descriptor_block = bytes[offset..(offset+18)]
      pixel_clock = descriptor_block[1]>>8 + descriptor_block[0]
      puts
      print "  Extension Block #%u: " % index
      if pixel_clock > 0
        # Detailed Timing Descriptor block
        puts "Detailed Timing Descriptor"
      else
        # Other monitor descriptor block
        descriptor_type = descriptor_block[3]
        descriptor_data = descriptor_block[5..17]
        case descriptor_type
        when 0xff
          puts "Display Serial Number [%s]" % descriptor_data
        when 0xfe
          puts "Unspecified Text [%s]" % descriptor_data
        when 0xfd
          puts "Display Range Limits"
        when 0xfc
          puts "Display Name [%s]" % descriptor_data
        when 0xfb
          puts "Additional White Point Data"
        when 0xfa
          puts "Additional Standard Timing Identifiers"
        when 0xf9
          puts "Display Color Management"
        when 0xf8
          puts "CVT 3-byte Timing Codes"
        when 0xf7
          puts "Additional Standard Timing"
        when 0x10
          puts "Dummy Identifier"
        when 0x00..0x0f # manufacturer reserved descriptors
          puts "Manufacturer Reserved Descriptor (type 0x02x)" % descriptor_type
          puts "    Data: %s" % descriptor_data.map{|b|"%02x "%b}.join
        else
          puts "Undefined Monitor Descriptor (type 0x%02x)" % descriptor_type
          puts "    Data: %s" % descriptor_data.map{|b|"%02x "%b}.join
        end
      end
    end
  end

end

### MAIN

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
  bytes = disp["edid_hex"].scan(/../).map{|x|Integer("0x#{x}")}.flatten

  # Retrieve monitor model from EDID data
  monitor_name=[disp["edid_hex"].match(/000000fc00((?:(?!0a)[0-9a-f][0-9a-f]){1,13})/){|m|m[1]}.to_s].pack("H*")
  if monitor_name.empty?
    monitor_name = "Display"
  end

  # Show some info
  puts
  puts "Found display '#{monitor_name}': vendorid #{disp["vendorid"]}, productid #{disp["productid"]}"

  bytes[24] = 0xf8

  # decode EDID block
  puts
  puts "Original EDID decode:"
  decode_edid( bytes )
  puts
  puts "EDID data:"
  puts disp["edid_hex"]

  puts
  puts "Patching EDID..."
  puts "  Setting color support to RGB 4:4:4 only"
  bytes[24] &= ~(0b11000)

  # Recalculate EDID checksum
  bytes[127] = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
  puts "  Recalculated checksum: 0x%02x" % bytes[127]

  # Optional - remove extension block(s)
  #puts "removing extension block"
  #bytes = bytes[0..127]
  #bytes[126] = 0

  puts
  puts "Patched EDID decode:"
  decode_edid (bytes)
  puts
  puts "EDID data:"
  new_edid = bytes.map{|b|"%02x"%b}.join
  puts new_edid
  puts
  puts "Difference:"
  puts diff(disp["edid_hex"], new_edid)

  $tab = "\t"
  def plist_key_value( sp, key, type, value )
    str =  "#{sp}<key>#{key.to_s}</key>\n"
    str += "#{sp}<#{type}>#{value.to_s}</#{type}>"
    return str
  end

  # Write an edid patch stanza
  def plist_edid_patch( sp, offset, bytes )
    str = "#{sp}<dict>\n"
    str += plist_key_value( sp + $tab, "offset", "integer", offset ) + "\n"
    str += plist_key_value( sp + $tab, "data", "data", Base64.strict_encode64( bytes.pack('C*') ).to_s ) + "\n"
    str += "#{sp}</dict>"
    return str
  end

  dir = "DisplayVendorID-%x" % disp["vendorid"]
  file = "DisplayProductID-%x" % disp["productid"]
  puts
  puts "Generating EDID patch: %s/%s" % [dir, file]
  Dir.mkdir(dir) rescue nil
  f = File.open("%s/%s" % [dir, file], 'w')
  #plist_key_value( f, sp, "IODisplayEDID", "data", Base64.strict_encode64( bytes.pack('C*') ).to_s )
  f.write <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
#{ plist_key_value( $tab, "DisplayVendorID", "integer", disp["vendorid"] ) }
#{ plist_key_value( $tab, "DisplayProductID", "integer", disp["productid"] ) }
#{ plist_key_value( $tab, "DisplayProductName", "string", "#{monitor_name} (RGB 4:4:4)" ) }
#{$tab}<key>edid-patches</key>
#{$tab}<array>
#{ plist_edid_patch( $tab + $tab, 24, bytes[24..24] ) }
#{$tab}</array>
</dict>
</plist>
PLIST
  f.close
  puts "\n"

end   # displays.each

