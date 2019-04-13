# patch-edid
Fork of Gist from https://gist.github.com/adaugherity/7435890 that forces monitor color format to RGB Full Range.

Changes:
  * Monitor name is properly extracted from the EDID data without extraneous junk at the end.
  * Some EDID values and feature flags are parsed and displayed.
  * Display override plist now patches the EDID instead of replacing it.  This should work properly in a multi-monitor setup.

Credit to Marcus for a faster update method that avoids disabling System Integrity Protection saving a reboot.
https://www.mathewinkson.com/2013/03/force-rgb-mode-in-mac-os-x-to-fix-the-picture-quality-of-an-external-monitor#comment-15886

##TO USE:

1.) Start by connecting the display to be modified and running the patch-edid.rb script.

It will generate a patchfile for each connected external display.  No special rights are required.

2.) Boot to into the recovery system (Hold Cmd+R during boot).

3.) Mount your system disk using Disk Utility.  If your system is encrypted with filevault you will need to enter your master password to unlock it.

Your system disk will be mounted under /Volumes/ (e.g. “/Volumes/Macintosh HD/”).  All your files are accessible here and you have write permissions to the “Overrides” folder. 

4.) Open a terminal and copy the DisplayVendor-directory from your users folder. Remember that every path is now prefixed by “/Volumes/Macintosh HD/”.

This example assumes the script is located in a folder “EDID-Fix” on the user's the desktop.

-bash-3.2# cp -r /Volumes/Macintosh\ HD/Users/marcus/Desktop/EDID-Fix/DisplayVendorID-* /Volumes/Macintosh\ HD/System/Library/Displays/Contents/Resources/Overrides/

If you only want to patch a single display be sure to adjust the command to copy only the desired folder.

5.) Reboot to your system
