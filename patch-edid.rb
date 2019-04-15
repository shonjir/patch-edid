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
#### PLIST CONFIG OPTIONS
PLIST_WRITE_FULL_EDID = false

# Optional text to append to DisplayProductName
# Leave empty to add nothing
PLIST_TAG_SHOW_OPTIONS = false
PLIST_TAG_DEFAULT = "RGB"

#### AVAILABLE OVERRIDE FLAGS
# EDID mods
SET_EDID14 = "EDID14"
SET_RGB444 = "RGB444"
NO_SRGB = "!SRGB"
NO_EXTENSIONS = "!EXT"
# Extension mods
NO_CTA_VSD_HDMI = "!HDMI"
NO_CTA_VSD_HDMIFORUM = "!FORUM"
NO_CTA_UNDERSCAN = "!UNDERSCAN"
NO_CTA_YCBCR = "!YCBCR"
NO_CTA_Y444 = "!Y444"
NO_CTA_Y422 = "!Y422"

# Override flags
# Either NO_EXTENSIONS or NO_CTA_VSD_HDMI fixes color format issues on Mac
$mac_hdmi_color_fix = [NO_CTA_VSD_HDMI]
$overrides = [NO_CTA_VSD_HDMI]

# Patch descriptors for patch generation
# Should do this by comparing EDID block but this avoids need for intelligent diff
$patchset = []

# Show diff between two strings
def diff( s1, s2 )
  t = s1.chars
  return s2.chars.map{|c| c == t.shift ? '-' : c}.join
end

# Decode 18 byte edid timing/monitor descriptor block
def edid_decode_dtd( bytes, offset )
  print "  "
  pixel_clock = ((bytes[offset+1])<<8) + bytes[offset+0]
  if pixel_clock > 0
    # Detailed Timing Descriptor data
    puts "Detailed Timing Descriptor: %u MHz" % (pixel_clock / 100)
  else
    # Monitor Descriptor data
    descriptor_flag2 = bytes[offset+2] # reserved, should be 0
    descriptor_type = bytes[offset+3]
    descriptor_flag4 = bytes[offset+4] # reserved, should be 0
    data_start = offset+5
    data_end = offset+17
    case descriptor_type
    when 0xff
      puts "Display Serial Number: %s" % bytes[data_start..data_end].map{|c|"%c"%c}.join.split("\n")
    when 0xfe
      puts "Unspecified Text: %s" % bytes[data_start..data_end].map{|c|"%c"%c}.join.split("\n")
    when 0xfd
      puts "Display Range Limits Descriptor"
    when 0xfc
      puts "Display Name: %s" % bytes[data_start..data_end].map{|c|"%c"%c}.join.split("\n")
    when 0xfb
      puts "Additional White Point Data"
    when 0xfa
      puts "Additional Standard Timing Identifiers"
    when 0xf9
      puts "Display Color Management (DCM) Descriptor"
    when 0xf8
      puts "CVT 3-byte Timing Codes"
    when 0xf7
      puts "Additional Standard Timing Descriptor"
    when 0x10
      puts "Dummy Descriptor"
    when 0x00..0x0f # manufacturer reserved descriptors
      puts "Manufacturer Reserved Descriptor (type 0x02x)" % descriptor_type
      puts "    Data: %s" % bytes[data_start..data_end].map{|b|"%02x"%b}.join(' ')
    else
      puts "Undefined Monitor Descriptor (type 0x%02x)" % descriptor_type
      puts "    Data: %s" % bytes[data_start..data_end].map{|b|"%02x"%b}.join(' ')
    end
  end
end

# Decode CTA VSD HDMI block
def edid_decode_cta_vsd_hdmi( bytes, ptr, length, sp )
  # Set to unknown OUI to disable
  if $overrides.include? NO_CTA_VSD_HDMI
    puts "PATCH[#{ptr+1}]: Clearing HDMI Licensing block"
    for i in 1..length
      bytes[ptr+i] = 0x00
    end
    $patchset.push ({ :range=>(ptr+1)..(ptr+length) })
  end
  puts sp + "Source: %s" % bytes[ptr+4..ptr+5].map{|b|"%02x"%b}.join.split("").join('.')

  # Flag byte 6 - feature flags
  flags=ptr+6
  if 0 != (bytes[flags] & (0x80))
    puts sp + "Supports_AI"
  end
  if 0 != (bytes[flags] & (0x40))
    puts sp + "DC_48bit 16-bit deep color"
  end
  if 0 != (bytes[flags] & (0x20))
    puts sp + "DC_36bit 12-bit deep color"
  end
  if 0 != (bytes[flags] & (0x10))
    puts sp + "DC_30bit 10-bit deep color"
  end
  if 0 != (bytes[flags] & (0x08))
    puts sp + "DC_Y444 in deep color modes"
  end
  if 0 != (bytes[flags] & (0b0110))
    puts sp + "Reserved"
  end
  if 0 != (bytes[flags] & (0x01))
    puts sp + "DVI Dual Link Operation"
  end

  # Flag byte 8 - content types
  if length > 7
    flags=ptr+8
    if 0 != (bytes[flags] & 0x0f)
      list = []
      if 0 != (bytes[flags] & (0x01))
        list.push("Graphics")
      end
      if 0 != (bytes[flags] & (0x02))
        list.push("Photo")
      end
      if 0 != (bytes[flags] & (0x04))
        list.push("Cinema")
      end
      if 0 != (bytes[flags] & (0x08))
        list.push("Game")
      end
      puts sp + "Supported content types: %s" % list.join(", ")
    end

  end
end

# Decode CTA VSD HDMI Forum block
def edid_decode_cta_vsd_hdmi_forum( bytes, ptr, length, sp )
  vsd_version = bytes[ptr+4]
  puts sp + "Version: #{vsd_version}"
  # Set to unknown OUI to disable
  # Should disable if no HDMI block
  if $overrides.include? NO_CTA_VSD_HDMIFORUM
    puts "PATCH[#{ptr+1}]: Clearing HDMI Forum block"
    for i in 1..length
      bytes[ptr+i] = 0
    end
    $patchset.push ({ :range=>(ptr+1)..(ptr+length) })
  end
  # Flag byte 6
  if 0 != (bytes[ptr+6] & (0x80))
    puts sp + "SCDC Present"
  end
  if 0 != (bytes[ptr+6] & (0x40))
    puts sp + "SCDC Read Request Capable"
  end
  if 0 != (bytes[ptr+6] & (0x10))
    puts sp + "Supports Color Content Bits"
  end
  if 0 != (bytes[ptr+6] & (0x08))
    puts sp + "Supports scrambling"
  end
  if 0 != (bytes[ptr+6] & (0x04))
    puts sp + "Supports 3D Independent View signaling"
  end
  if 0 != (bytes[ptr+6] & (0x02))
    puts sp + "Supports 3D Dual View signaling"
  end
  if 0 != (bytes[ptr+6] & (0x01))
    puts sp + "Supports 3D OSD Disparity signaling"
  end
  if 0 != (bytes[ptr+7] & (0x04))
    puts sp + "Supports 16-bits/component Deep Color 4:2:0 Encoding"
  end
  if 0 != (bytes[ptr+7] & (0x02))
    puts sp + "Supports 12-bits/component Deep Color 4:2:0 Encoding"
  end
  if 0 != (bytes[ptr+7] & (0x01))
    puts sp + "Supports 10-bits/component Deep Color 4:2:0 Encoding"
  end
  # Flag byte 8
  if length > 7
    if 0 != (bytes[ptr+8] & (0x20))
      puts sp + "Supports Mdelta"
    end
    if 0 != (bytes[ptr+8] & (0x10))
      puts sp + "Supports CinemaVRR rates"
    end
    if 0 != (bytes[ptr+8] & (0x08))
      puts sp + "Supports negative Mvrr"
    end
    if 0 != (bytes[ptr+8] & (0x04))
      puts sp + "Supports Fast Vactive"
    end
    if 0 != (bytes[ptr+8] & (0x02))
      puts sp + "Supports Auto Low-Latency Mode"
    end
    if 0 != (bytes[ptr+8] & (0x01))
      puts sp + "Supports FAPA blanking after first line"
    end
  end
  # Flag byte 11
  if length > 10
    if 0 != (bytes[ptr+11] & (0x80))
      puts sp + "Supports VESA DSC 1.2a compression"
    end
    if 0 != (bytes[ptr+11] & (0x40))
      puts sp + "Supports Compressed Video Transport for 4:2:0 Encoding"
    end
    if 0 != (bytes[ptr+11] & (0x08))
      puts sp + "Supports Compressed Video Transport (any valid 1/16th bit bpp)"
    end
    if 0 != (bytes[ptr+11] & (0x04))
      puts sp + "Supports 16 bpc Compressed Video"
    end
    if 0 != (bytes[ptr+11] & (0x02))
      puts sp + "Supports 12 bpc Compressed Video"
    end
    if 0 != (bytes[ptr+11] & (0x01))
      puts sp + "Supports 10 bpc Compressed Video"
    end
  end
end

# Decode EDID CTA Extension
def edid_decode_cta_block ( bytes, offset, sp )
  dtd_offset = bytes[offset+2]
  dtd_count = bytes[offset+3] & (0b1111)
  flags=offset+3  # location of feature flags
  if 0 != (bytes[flags] & (0b10000000))
    puts sp + "Underscans by default"
    # Underscan support indicated in byte 3, bits 8
    if $overrides.include? NO_CTA_UNDERSCAN
      puts "PATCH[#{flags}]: Clearing underscan flag"
      bytes[flags] &= ~(0b10000000)
      $patchset.push ({ :byte=>flags })
    end
  end
  if 0 != (bytes[flags] & (0b01000000))
    puts sp + "Basic audio support"
  end
  if 0 != (bytes[flags] & (0b00100000))
    puts sp + "Supports YCbCr 4:4:4"
    # YCbCr 4:4:4 support indicated in byte 3, bits 5
    if $overrides.include? NO_CTA_Y444 or NO_CTA_YCBCR
      puts "PATCH[#{flags}]: Clearing YCbCr 4:4:4 support"
      bytes[flags] &= ~(0b00100000)
      $patchset.push ({ :byte=>flags })
    end
  end
  if 0 != (bytes[flags] & (0b00010000))
    puts sp + "Supports YCbCr 4:2:2"
    # YCbCr 4:2:2 support indicated in byte 3, bits 4
    if $overrides.include? NO_CTA_Y422 or NO_CTA_YCBCR
      puts "PATCH[#{flags}]: Clearing YCbCr 4:2:2 support"
      bytes[flags] &= ~(0b00010000)
      $patchset.push ({ :byte=>flags })
    end
  end

  # DTD BLOCK DECODER
  # DTD blocks begin at dtd_offset
  puts sp + "Supported Native Detailed Modes: %u" % dtd_count
  if dtd_offset >= 4
    ptr = offset + dtd_offset
    while ptr < offset + 126
      if (bytes[ptr] + bytes[ptr+1] == 0)
        break
      end
      edid_decode_dtd( bytes, ptr )
      ptr += 18
    end
  end

  # DATA BLOCK DECODER
  # data blocks begin at byte 4 through dtd_offset-1
  if dtd_offset > 4
    ptr = offset + 4
    while ptr < offset + dtd_offset
      type = (bytes[ptr] & (0b11100000))>>5
      length = bytes[ptr] & (0b00011111)
      print "byte #{ptr}: "
      case type
      when 1
        puts sp + "Audio data block"
      when 2
        puts sp + "Video data block"
        puts sp + "  Data: %s" % bytes[ptr..ptr+length].map{|b|"%02x"%b}.join(' ')
      when 3 # CTA Vendor-specific data block
        vsd_oui = bytes[ptr+1..ptr+3].reverse.map{|b|"%02x"%b}.join
        print sp + "Vendor-specific data block, OUI %s " % vsd_oui
        case vsd_oui
        when "000c03" # hdmi
          puts "(HDMI Licensing)"
          edid_decode_cta_vsd_hdmi( bytes, ptr, length, "    " )
        when "c45dd8" # HDMI Forum
          puts "(HDMI Forum)"
          edid_decode_cta_vsd_hdmi_forum( bytes, ptr, length, "    " )
        else
          puts "(UNKNOWN)"
          puts sp + "  Data: %s" % bytes[ptr..ptr+length].map{|b|"%02x"%b}.join(' ')
        end
      when 4
        puts sp + "Speaker Allocation Block"
      when 5
        puts sp + "VESA DTC data block"
      when 7
        tag_type = bytes[ptr+1]
        print sp + "Extended tag: "
        case tag_type
        when 0
          puts "Video capability data"
        when 1
          puts "Vendor-specific video data"
        when 2
          puts "VESA video display device data"
        when 3
          puts "VESA video timing data"
        when 4
          puts "Reserved for HDMI video data"
        when 5
          puts "Colorimetry data"
        when 6
          puts "HDR static metadata"
        when 7
          puts "HDR dynamic metadata"
        when 0xd
          puts "Video format preference data"
        when 0xe
          puts "YCbCr 4:2:0 video data"
        when 0xf
          puts "YCbCr 4:2:0 capability map data"
        when 0x10
          puts "Reserved for CTA misc audio fields"
        when 0x11
          puts "Vendor-specific audio data"
        when 0x12
          puts "HDMI audio data"
        when 0x13
          puts "Room configuration data"
        when 0x14
          puts "Speaker location data"
        when 0x20
          puts "InfoFrame data"
        when 6..12
          puts "Reserved for video-related blocks (%02x)" % tag_type
        when 19..31
          puts "Reserved for video-related blocks (%02x)" % tag_type
        else
          puts "Reserved (%02x)" % tag_type
        end

      else
        puts sp + "Reserved Data Type %u" % type
        puts sp + "  Bytes: %s" % bytes[ptr..ptr+length].map{|b|"%02x"%b}.join(' ')
      end
      ptr += length + 1
    end
  end

end

# Decode EDID Extension Block
def edid_decode_extension( bytes, offset )
  extension_tag = bytes[offset+0]
  extension_revision = bytes[offset+1]
  extension_checksum = bytes[offset+127]
  puts
  case extension_tag
  when 0x00
    puts "Timing Extension"
    puts "  Extension revision %u" % extension_revision
  when 0x01
    puts "LCD Timings Extension"
    puts "  Extension revision %u" % extension_revision
  when 0x02   # CTA EDID Timing Extension
    puts "CTA EDID Additional Timing Data Extension"
    puts "  Revision %u" % extension_revision
    edid_decode_cta_block( bytes, offset, "  " )
  when 0x10
    puts "Video Timing Block"
    puts "Extension revision %u" % extension_revision
  when 0x20
    puts "EDID 2.0 Extension"
    puts "Extension revision %u" % extension_revision
  when 0x30
    puts "Color information type 0"
    puts "Extension revision %u" % extension_revision
  when 0x40 # VESA standard has this as DVI feature data
    puts "Display Information Extension (DI-EXT)"
  when 0x50 # VESA standard has this as Touch screen data
    puts "Localized String Extension (LS-EXT)"
  when 0x60
    puts "Microdisplay Interface Extension (MI-EXT)"
  when 0x70
    puts "Display ID Extension"
  when 0xa7, 0xaf, 0xbf
    puts "Display Transfer Characteristics Data Block (DTCDB)"
  when 0xf0
    puts "EDID Block Map"
  when 0xff
    puts "Manufacturer Defined Extension"
    puts "    Data: %s" % extension_data.map{|b|"%02x "%b}.join
  else
    puts "Undefined Extension Type 0x%02x" % extension_tag
    puts "    Data: %s" % extension_data.map{|b|"%02x "%b}.join
  end
end

# Decode EDID block
def edid_decode( bytes )
  puts "EDID version #{bytes[18]}.#{bytes[19]}"
  edid_version = (bytes[18]<<8) + (bytes[19])
  if $overrides.include? SET_EDID14
    puts "PATCH[18..19]: Setting EDID 1.4"
    bytes[18] = 1
    bytes[19] = 4
    $patchset.push ({ :range=>18..19 })
  end
  puts "  Length: %u" % bytes.length
  # Display type in byte 20, bit 7
  formats = ["Monochrome / Grayscale", "RGB Color", "Non-RGB Color", "Undefined"]
  edid14_formats = ["RGB 4:4:4", "RGB 4:4:4 + YCrCb 4:4:4", "RGB 4:4:4 + YCrCb 4:2:2", "RGB 4:4:4 + YCrCb 4:4:4 + YCrCb 4:2:2"]
  if 0 != (bytes[20] & (0x80))
    display_type = "Digital"
    # EDID 1.4 changes definition of format bits
    if edid_version > 0x0103
      formats = edid14_formats
    end
  else
    display_type = "Analog"
  end
  # Color format in byte 24, bits 4-3
  color_format = (bytes[24] & (0b00011000))>>3
  puts "  #{display_type} input (#{formats[color_format]})"
  # PATCH COLOR FORMAT
  if $overrides.include? SET_RGB444
    puts "PATCH[24]: Setting monochrome / RGB 4:4:4 mode"
    bytes[24] &= ~(0b11000)
    $patchset.push ({ :byte=>24 })
  end
  #
  # dpms features in byte 24, bits 7-5
  if 0 != (bytes[24] & (0b11100000))
    dpms = []
    if 0 != (bytes[24] & (0b10000000))
      dpms.push("standby")
    end
    if 0 != (bytes[24] & (0b01000000))
      dpms.push("suspend")
    end
    if 0 != (bytes[24] & (0b00100000))
      dpms.push("active-off")
    end
    puts "  DPMS features: #{dpms.join(', ')}"
  end
  # Color space in byte 24, bit 2
  if 0 != (bytes[24] & (0b00000100))
    puts "  Standard sRGB color space"
    # OVERRIDE color space
    if $overrides.include? NO_SRGB
      puts "PATCH[24]: Clearing sRGB color space bit"
      bytes[24] &= ~(0b00000100)
      $patchset.push ({ :byte=>24 })
    end
  end
  if 0 != (bytes[24] & (0b10))
    puts "  First detailed timing is preferred"
  end
  if 0 != (bytes[24] & (0b1))
    puts "  Default GTF supported"
  end

  # Timing/monitor descriptor blocks are 18 bytes in length from byte 54 to 125
  puts "Standard Descriptor Blocks"
  for index in (0..3)
    offset = 54 + index * 18
    edid_decode_dtd( bytes, offset )
  end

  # Extension blocks are 128 bytes in length beginning at byte 128
  # if block count is 1, first block is an extension
  # otherwise first block is an extension block map
  extension_count = bytes[126]
  puts "Extension blocks: #{extension_count}"
  # Iterate through extension blocks
  for index in (0..extension_count-1)
    offset = 128 + index*128
    edid_decode_extension( bytes, offset )
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
  orig_edid = bytes.dup

  # Retrieve monitor model from EDID data
  display_name=[disp["edid_hex"].match(/000000fc00((?:(?!0a)[0-9a-f][0-9a-f]){1,13})/){|m|m[1]}.to_s].pack("H*")
  if display_name.empty?
    display_name = "Display"
  end

  # Show some info
  puts
  puts "Found display '#{display_name}': vendorid #{disp["vendorid"]}, productid #{disp["productid"]}"

  # decode EDID block
  puts
  puts "EDID decode:"
  output = edid_decode( bytes )

  # Clear extension block(s)
  if $overrides.include? NO_EXTENSIONS
    # Optional - remove extension block(s)
    puts
    puts "PATCH[128]: Removing Extension Block(s)"
    bytes[126] = 0
    length = bytes.length
    # Truncate EDID
    bytes = bytes[0..127]
    if $overrides.include? PLIST_WRITE_FULL_EDID
    else
      # Zero extension block if patching
      bytes += Array.new(length - 128, 0) if length > 128
      $patchset.push ({ :range => 128..(bytes.length) })
    end
  end

  # Recalculate EDID checksum
  puts
  puts "Applied patches: %s" % $overrides.join(", ")

  checksum = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
  if bytes[127] != checksum
    bytes[127] = checksum
    puts "New EDID checksum: 0x%02x" % checksum
  end

  # Recalculate Extension checksums
  if bytes[126] > 0
    extension_count = bytes[126]
    # Iterate through extension blocks
    for index in (0..extension_count-1)
      offset = 128 + index*128
      extension_tag = bytes[offset+0]
      # Recalculate extension checksum
      checksum = (0x100-(bytes[(offset+0)..(offset+126)].reduce(:+) % 256)) % 256
      if bytes[offset+127] != checksum
        bytes[offset+127] = checksum
        puts "New extension checksum (block %u): 0x%02x" % [offset, checksum]
      end
    end
  end

  # DISPLAY EDID DELTA
  puts
  puts "Original EDID:"
  puts disp["edid_hex"]
  puts
  puts "New EDID:"
  new_edid = bytes.map{|b|"%02x"%b}.join
  puts new_edid
  puts
  puts "Changes:"
  puts diff(disp["edid_hex"], new_edid)

  # Write a plist key value pair
  def plist_key_value( sp, key, type, value )
    p = []
    p.push "#{sp}<key>#{key.to_s}</key>"
    p.push "#{sp}<#{type}>#{value.to_s}</#{type}>"
    return p
  end

  # Write a plist multiline set
  def plist_multi( sp, key, list )
    p = []
    p.push "#{sp}<#{key.to_s}>"
    p.push list
    p.push "#{sp}</#{key.to_s}>"
    return p
  end

  # Write an edid patch stanza
  def plist_edid_patch( sp, offset, bytes )
    p = []
    p.push "#{sp}<dict>"
    p.push plist_key_value( sp + "  ", "offset", "integer", offset )
    p.push plist_key_value( sp + "  ", "data", "data", Base64.strict_encode64( bytes.pack('C*') ).to_s )
    p.push "#{sp}</dict>"
    return p
  end

  # Generate override plist
  dir = "DisplayVendorID-%x" % disp["vendorid"]
  file = "DisplayProductID-%x" % disp["productid"]
  puts
  puts "Writing EDID Override: %s/%s" % [dir, file]
  plist = []
  plist.push '<?xml version="1.0" encoding="UTF-8"?>'
  plist.push '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  plist.push '<plist version="1.0">'
  dict = []
  dict.push plist_key_value( "  ", "DisplayVendorID", "integer", disp["vendorid"] )
  dict.push plist_key_value( "  ", "DisplayProductID", "integer", disp["productid"] )
  if PLIST_TAG_SHOW_OPTIONS
    display_name += " (#{$overrides.join(',')})"
  else
    display_name += (PLIST_TAG_DEFAULT) ? " (#{PLIST_TAG_DEFAULT})" : ""
  end
  dict.push plist_key_value( "  ", "DisplayProductName", "string", "#{display_name}")
  puts "  DisplayProductName: #{display_name}"
  puts "  DisplayVendorID:    #{disp["vendorid"]}"
  puts "  DisplayProductID:   #{disp["productid"]}"
  if PLIST_WRITE_FULL_EDID
    puts "  Using full EDID"
    dict.push plist_key_value( "  ", "IODisplayEDID", "data", Base64.strict_encode64( bytes.pack('C*') ).to_s )
  else
    puts "  Using patch set"
    # generate patch set
    dict.push '  <key>edid-patches</key>'
    patchlist = []
    $patchset.uniq.each do |p|
      p.each do |key,value|
        case key
        when :byte
          patchlist.push plist_edid_patch( "    ", value, bytes[value..value] )
        when :range
          patchlist.push plist_edid_patch( "    ", value.begin, bytes[value] )
        else
          puts "BUG: #{key}=>#{value}"
        end
      end
    end
    dict.push plist_multi( "  ", "array", patchlist )
  end
  plist.push plist_multi( "", "dict", dict )
  plist.push '</plist>'

  Dir.mkdir(dir) rescue nil
  f = File.open("%s/%s" % [dir, file], 'w')
  f.write plist.join("\n") + "\n"
  f.close
  puts "Complete."
  puts

end   # displays.each

