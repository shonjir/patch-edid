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

patch_cea = false
full_edid = true

# Show diff between two strings
def diff( s1, s2 )
  t = s1.chars
  return s2.chars.map{|c| c == t.shift ? '-' : c}.join
end

# Decode 18 byte edid timing/monitor descriptor block
def edid_decode_dtd( dtd )
  # first line prefix
  if dtd.length != 18
    puts "BUG: Illegal descriptor block (length %u)" % dtd.length
    return
  end
  print "  "
  pixel_clock = ((dtd[1])<<8) + dtd[0]
  if pixel_clock > 0
    # Detailed Timing Descriptor data
    puts "Detailed Timing Descriptor: %u MHz" % (pixel_clock / 100)
  else
    # Monitor Descriptor data
    descriptor_flag2 = dtd[2] # reserved, should be 0
    descriptor_type = dtd[3]
    descriptor_flag4 = dtd[4] # reserved, should be 0
    descriptor_data = dtd[5..17]
    case descriptor_type
    when 0xff
      puts "Display Serial Number: %s" % descriptor_data.map{|c|"%c"%c}.join.split("\n")
    when 0xfe
      puts "Unspecified Text: %s" % descriptor_data.map{|c|"%c"%c}.join.split("\n")
    when 0xfd
      puts "Display Range Limits Descriptor"
    when 0xfc
      puts "Display Name: %s" % descriptor_data.map{|c|"%c"%c}.join.split("\n")
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
      puts "    Data: %s" % descriptor_data.map{|b|"%02x"%b}.join(' ')
    else
      puts "Undefined Monitor Descriptor (type 0x%02x)" % descriptor_type
      puts "    Data: %s" % dtd.map{|b|"%02x"%b}.join(' ')
    end
  end
end

# Decode EDID Extension Block
def edid_decode_extension( extension )
  extension_tag = extension[0]
  extension_revision = extension[1]
  extension_checksum = extension[127]
  puts
  case extension_tag
  when 0x00
    puts "Timing Extension"
    puts "  Extension revision %u" % extension_revision
  when 0x01
    puts "LCD Timings Extension"
    puts "  Extension revision %u" % extension_revision
  when 0x02   # CEA EDID Timing Extension
    puts "CEA EDID Additional Timing Data Extension"
    puts "  Extension revision %u" % extension_revision
    dtd_offset = extension[2]
    dtd_count = extension[3] & (0b1111)
    data_blocks = extension[4..(dtd_offset-1)]
    dtd_blocks = extension[dtd_offset..126]
    features = []
    if 0 != (extension[3] & (0b10000000))
      features.push("Underscans by default")
    end
    if 0 != (extension[3] & (0b01000000))
      features.push("Basic audio support")
    end
    if 0 != (extension[3] & (0b00100000))
      features.push("Supports YCbCr 4:4:4")
    end
    if 0 != (extension[3] & (0b00010000))
      features.push("Supports YCbCr 4:2:2")
    end
    puts "    " + features.join("\n    ")

    # DATA BLOCK DECODER
    # data blocks begin at byte 4
    if data_blocks.length
      offset = 0
      while offset < data_blocks.length
        type = (data_blocks[offset] & (0b11100000))>>5
        length = data_blocks[offset] & (0b00011111)
        block = data_blocks[(offset)..(offset+length)]
        case type
        when 1
          puts "  Audio data block"
        when 2
          puts "  Video data block"
        when 3 # CEA Vendor-specific data block
          vsd_oui = block[1..3].reverse.map{|b|"%02x"%b}.join
          case vsd_oui
          when "000c03" # hdmi
            vsd_vendor = "HDMI Licensing"
            output = []
            output.push("Source: %s" % block[4..5].map{|b|"%02x"%b}.join.split("").join('.'))
            if 0 != (block[6] & (0x80))
              output.push("Supports_AI")
            end
            if 0 != (block[6] & (0x40))
              output.push("DC_48bit 16-bit deep color")
            end
            if 0 != (block[6] & (0x20))
              output.push("DC_36bit 12-bit deep color")
            end
            if 0 != (block[6] & (0x10))
              output.push("DC_30bit 10-bit deep color")
            end
            if 0 != (block[6] & (0x08))
              output.push("DC_Y444 in deep color modes")
            end
            if 0 != (block[6] & (0b0110))
              output.push("Reserved")
            end
            if 0 != (block[6] & (0x01))
              output.push("DVI Dual Link Operation")
            end
          when "c45dd8" # HDMI Forum
            vsd_vendor = "HDMI Forum"
            vsd_version = block[4]
            output = []
            if 0 != (block[5] & (0x80))
              output.push("Supports_AI")
            end
            if 0 != (block[5] & (0x40))
              output.push("SCDC Present")
            end
            if 0 != (block[5] & (0x20))
              output.push("SCDC Read Request Capable")
            end
            if 0 != (block[5] & (0x10))
              output.push("Supports Color Content Bits")
            end
            if 0 != (block[5] & (0x08))
              output.push("Supports scrambling")
            end
            if 0 != (block[5] & (0x04))
              output.push("Supports 3D Independent View signaling")
            end
            if 0 != (block[5] & (0x02))
              output.push("Supports 3D Dual View signaling")
            end
            if 0 != (block[5] & (0x01))
              output.push("Supports 3D OSD Disparity signaling")
            end
            if 0 != (block[6] & (0x04))
              output.push("Supports 16-bits/component Deep Color 4:2:0 Encoding")
            end
            if 0 != (block[6] & (0x02))
              output.push("Supports 12-bits/component Deep Color 4:2:0 Encoding")
            end
            if 0 != (block[6] & (0x01))
              output.push("Supports 10-bits/component Deep Color 4:2:0 Encoding")
            end
            if length > 7
              if 0 != (block[7] & (0x20))
                output.push("Supports Mdelta")
              end
              if 0 != (block[7] & (0x10))
                output.push("Supports CinemaVRR rates")
              end
              if 0 != (block[7] & (0x08))
                output.push("Supports negative Mvrr")
              end
              if 0 != (block[7] & (0x04))
                output.push("Supports Fast Vactive")
              end
              if 0 != (block[7] & (0x02))
                output.push("Supports Auto Low-Latency Mode")
              end
              if 0 != (block[7] & (0x01))
                output.push("Supports FAPA blanking after first line")
              end
            end
            if length > 10
              if 0 != (block[10] & (0x80))
                output.push("Supports VESA DSC 1.2a compression")
              end
              if 0 != (block[10] & (0x40))
                output.push("Supports Compressed Video Transport for 4:2:0 Encoding")
              end
              if 0 != (block[10] & (0x08))
                output.push("Supports Compressed Video Transport (any valid 1/16th bit bpp)")
              end
              if 0 != (block[10] & (0x04))
                output.push("Supports 16 bpc Compressed Video")
              end
              if 0 != (block[10] & (0x02))
                output.push("Supports 12 bpc Compressed Video")
              end
              if 0 != (block[10] & (0x01))
                output.push("Supports 10 bpc Compressed Video")
              end
            end
          else
            vsd_vendor = "UNKNOWN"
            output.push("Data: %s" % block.map{|b|"%02x"%b}.join(' '))
          end
          puts "  Vendor-specific data block, OUI %s (%s)" % [vsd_oui, vsd_vendor]
          puts "    " + output.join("\n    ")

        when 4
          puts "  Speaker Allocation Block"
        when 5
          puts "  VESA DTC data block"
        when 7
          print "  Extended tag: "
          tag_type = block[1]
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
            puts "Reserved for CEA misc audio fields"
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
          puts "  Reserved Data Type %u" % type
          puts "    Bytes: %s" % block.map{|b|"%02x"%b}.join(' ')
        end
        offset += length + 1
      end
    end

    # DTD BLOCK DECODER
    # DTD blocks begin at dtd_offset
    puts "  Supported Native Detailed Modes: %u" % dtd_count
    if dtd_offset >= 4
      offset = 0
      while offset < dtd_blocks.length
        dtd = dtd_blocks[offset..(offset+17)]
        if (dtd[0] + dtd[1] == 0)
          break
        end
        edid_decode_dtd( dtd )
        offset += 18
      end
    end
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
  puts "  Length: %u" % bytes.length
  # color format in byte 24, bits 4-3
  color_format = (bytes[24] & (0b11000))>>3
  # Display type in byte 20, bit 7
  if (bytes[20] & (0x80))>>7
    formats = ["RGB 4:4:4", "RGB 4:4:4 + YCrCb 4:4:4", "RGB 4:4:4 + YCrCb 4:2:2", "RGB 4:4:4 + YCrCb 4:4:4 + YCrCb 4:2:2"]
    display_type = "Digital"
  else
    formats = ["Monochrome / Grayscale", "RGB Color", "Non-RGB Color", "Undefined"]
    display_type = "Analog"
  end
  puts "  #{display_type} input (#{formats[color_format]})"
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
  end
  if 0 != (bytes[24] & (0b10))
    puts "  Preferred timing mode specified"
  end
  if 0 != (bytes[24] & (0b1))
    puts "  Default GTF supported"
  end

  # Timing/monitor descriptor blocks are 18 bytes in length from byte 54 to 125
  puts "Standard Descriptor Blocks"
  for index in (0..3)
    offset = 54 + index * 18
    data = bytes[offset..(offset+17)]
    edid_decode_dtd( data )
  end

  # Extension blocks are 128 bytes in length beginning at byte 128
  # if block count is 1, first block is an extension
  # otherwise first block is an extension block map
  extension_count = bytes[126]
  puts "Extension blocks: #{extension_count}"
  # Iterate through extension blocks
  for index in (0..extension_count-1)
    offset = 128 + index*128
    data = bytes[offset..(offset+127)]
    edid_decode_extension( data )
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

  # decode EDID block
  puts
  puts "EDID decode:"
  output = edid_decode( bytes )
  puts
  puts "EDID data:"
  puts disp["edid_hex"]

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

  puts
  puts "Patching EDID..."
  patches = []
  puts "  Setting digital type to RGB 4:4:4 only"
  bytes[24] &= ~(0b11000)
  patches.push plist_edid_patch( "    ", 24, bytes[24..24] )

  # Recalculate EDID checksum
  bytes[127] = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
  puts "  Updated checksum: 0x%02x" % bytes[127]

  # Optional - patch CEA extension block
  if patch_cea
    extension_count = bytes[126]
    # Iterate through extension blocks
    for index in (0..extension_count-1)
      offset = 128 + index*128
      extension_tag = bytes[offset+0]
      case extension_tag
      when 0x02   # CEA EDID Timing Extension
        # YCbCr support indicated in byte 3, bits 5 and 4
        puts "  Disabling CEA Extension YCbCr flags"
        bytes[offset+3] &= ~(0b00110000)
        patches.push plist_edid_patch( "    ", offset+3, bytes[(offset+3)..(offset+3)] )
        # Recalculate extension checksum
        bytes[offset+127] = (0x100-(bytes[(offset+0)..(offset+126)].reduce(:+) % 256)) % 256
        puts "  Updated checksum: 0x%02x" % bytes[offset+127]
      end
    end
  end

  # Optional - remove extension block(s)
  #puts "removing extension block"
  #bytes = bytes[0..127]
  #bytes[126] = 0

  puts
  puts "Patched EDID decode:"
  edid_decode( bytes )
  puts
  puts "EDID data:"
  new_edid = bytes.map{|b|"%02x"%b}.join
  puts new_edid
  puts
  puts "Difference:"
  puts diff(disp["edid_hex"], new_edid)

  puts
  puts "Generating EDID plist"
  plist = []
  plist.push '<?xml version="1.0" encoding="UTF-8"?>'
  plist.push '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  plist.push '<plist version="1.0">'
  dict = []
  dict.push plist_key_value( "  ", "DisplayVendorID", "integer", disp["vendorid"] )
  dict.push plist_key_value( "  ", "DisplayProductID", "integer", disp["productid"] )
  dict.push plist_key_value( "  ", "DisplayProductName", "string", "#{monitor_name} (RGB 4:4:4)" )
  if full_edid
    dict.push plist_key_value( "  ", "IODisplayEDID", "data", Base64.strict_encode64( bytes.pack('C*') ).to_s )
  else
    dict.push '  <key>edid-patches</key>'
    dict.push plist_multi( "  ", "array", patches )
  end
  plist.push plist_multi( "", "dict", dict )
  plist.push '</plist>'

  dir = "DisplayVendorID-%x" % disp["vendorid"]
  file = "DisplayProductID-%x" % disp["productid"]
  puts "Writing EDID Override: %s/%s" % [dir, file]
  Dir.mkdir(dir) rescue nil
  f = File.open("%s/%s" % [dir, file], 'w')
  f.write plist.join("\n")
  f.close
  puts "\n"

end   # displays.each

