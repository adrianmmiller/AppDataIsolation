ui_print "search for services-platform-compat-config.xml in /system/etc/compatconfig/"

#check /system/etc/compatconfig/services-platform-compat-config.xml exists
if [ -f /system/etc/compatconfig/services-platform-compat-config.xml ] ; then
    ui_print "services-platform-compat-config.xml found at: /system/etc/compatconfig/"
    ui_print "copying services-platform-compat-config.xml to $MODPATH"
    #copy /system/etc/compatconfig/services-platform-compat-config.xml to $MODPATH
    cp -af "/system/etc/compatconfig/services-platform-compat-config.xml" "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"
    ui_print "modifying $MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"

    #detect ARCH
    ui_print "Architecture: $ARCH"

    #rename xmlstarlet binary according to ARCH - we're not going to copy it and leave it on device, just use it once during install
    mv $MODPATH/xmlstarlet-$ARCH $MODPATH/xmlstarlet
    ui_print "Rename: $MODPATH/xmlstarlet-$ARCH to $MODPATH/xmlstarlet"

    #set perms for $MODPATH/xmlstarlet 
    chmod 0755 $MODPATH/xmlstarlet

    ui_print "Editing XML"
    #edit xml in place in "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml" 
    $MODPATH/xmlstarlet ed --inplace -r "//compat-change[@id="149391281"][starts-with(@name,"CTS_SYSTEM_API_CHANGEID")]/@enableSinceTargetSdk" -v enableAfterTargetSdk "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"
    $MODPATH/xmlstarlet ed --inplace -u "//compat-change[@id="149391281"][starts-with(@name,"CTS_SYSTEM_API_CHANGEID")]/@enableAfterTargetSdk" -v 1234 "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"
    $MODPATH/xmlstarlet ed --inplace -u "//compat-change[@id="143937733"][starts-with(@name,"APP_DATA_DIRECTORY_ISOLATION")]/@enableAfterTargetSdk" -v 0 "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"
else
    ui_print "services-platform-compat-config.xml NOT found at: /system/etc/compatconfig/"
    abort "module install will now abort"
fi

# delete xmlstarlet binaries to save space
rm -f $MODPATH/xmlstarlet*
