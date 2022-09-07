# App Data Isolation
## An attempt to block access, by other apps, to the private data directories for all supported API's (30+/Android 11+)

This module attempts to block access, by other apps, to the private data directories for all supported SDK API's (30+/Android 11+), using the information from the original article following this explanation of the modules actions

### What the module does:

- check for the existence of /system/etc/compatconfig/services-platform-compat-config.xml
- if found, it (to avoid using a static copy) copies this file to the modules own $MODPATH/system/etc/compatconfig/ directory
- then, using xmlstarlet (thanks to [ZackPtg5's Cross Compiled Binaries for Android](https://github.com/Zackptg5/Cross-Compiled-Binaries-Android), dynamically chosen to fit your ARCH), the $MODPATH/system/etc/compatconfig/services-platform-compat-config.xml is edited in place to make the changes noted in the original article, with addtional changes to the id="149391281" made that isnt in the original article (im not sure what this actually does at this stage but it was included for me to package). These changes are contained in the /common/install.sh file

```
$MODPATH/xmlstarlet ed --inplace -r "//compat-change[@id="149391281"][starts-with(@name,"CTS_SYSTEM_API_CHANGEID")]/@enableSinceTargetSdk" -v enableAfterTargetSdk "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"

$MODPATH/xmlstarlet ed --inplace -u "//compat-change[@id="149391281"][starts-with(@name,"CTS_SYSTEM_API_CHANGEID")]/@enableAfterTargetSdk" -v 1234 "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"

$MODPATH/xmlstarlet ed --inplace -u "//compat-change[@id="143937733"][starts-with(@name,"APP_DATA_DIRECTORY_ISOLATION")]/@enableAfterTargetSdk" -v 0 "$MODPATH/system/etc/compatconfig/services-platform-compat-config.xml"
```

- then the xmlstarlet binaries are deleted to save space (6Mb) on device
- on boot the following props are added using system.prop in the modules root folder
```
persist.zygote.app_data_isolation=1
persist.sys.vold_app_data_isolation_enabled=1
```

You can test for these props via terminal before and after module install to see theyre applied correctly via:

```
getprop persist.zygote.app_data_isolation
getprop persist.sys.vold_app_data_isolation_enabled
```

The module is designed to be fully reversible and leave no leftovers if you remove it

I was asked to package this module, it is not a method of my making, so please DO NOT ask me questions about the method thanks, nor to provide support if it doesnt do what youre expecting.....all such queries will go directly, with haste, to /dev/null


**Please note:** the included LICENSE only covers the module components provided by the excellent work of Zack5tpg's Magisk Module Extended, which is available for here for module creators

https://github.com/Zackptg5/MMT-Extended/

All other work is credited above and **no one may fork or re-present this module as their own for the purposes of trying to monetize this module or its content without all parties permission. The module comes specifically without an overall license for this intent.**

### Project Stats ###

![GitHub release (latest by date)](https://img.shields.io/github/v/release/stylemessiah/AppDataIsolation?label=Release&style=plastic) ![GitHub Release Date](https://img.shields.io/github/release-date/stylemessiah/AppDataIsolation?label=Release%20Date&style=plastic) ![GitHub Releases](https://img.shields.io/github/downloads/stylemessiah/AppDataIsolation/latest/total?label=Downloads%20%28Latest%20Release%29&style=plastic) ![GitHub All Releases](https://img.shields.io/github/downloads/stylemessiah/AppDataIsolation/total?label=Total%20Downloads%20%28All%20Releases%29&style=plastic)


---

Original Article, machine translated to English follows:

This article was transcoded by [Jian Yue SimpRead](http://ksria.com/simpread/), the original address [gist.github.com](https://gist.github.com/5ec1cff/b2a88d23c3d5f40a2c23fc785e80fc5f)

 > Enable data and Android/data isolation in Android 11+. GitHub Gist: instantly share code, notes, and snippets.

 Detecting package names is an important method for Android application security measures, and there are various methods. The conventional method of querying package names through PMS has been hidden by [HMA](https://github.com/Dr-TSNG/Hide-My-Applist), and as the Android version is updated, it is gradually [restricting applications to obtain arbitrary access] package name](https://developer.android.com/about/versions/11/privacy/package-visibility?hl=zh-cn) (although it is possible to declare the types that need to be queried), but there is a more insidious way , is to use the vulnerability of the /data/data directory or /sdcard/Android/data - the directories below them are all application data directories named after the package name, although these two directories cannot be listed directly, but any application has this The x permission of the directory (otherwise you cannot access your own data directory), so if you know the package name that needs to be detected, you can use stat and other system calls to determine whether the directory exists, and then determine the existence of the package name (success or Permission Denied indicates the file exist). This approach cannot be prevented by a simple hook (especially if a direct syscall bypasses the library function).

 However, Android 11 actually introduced some measures to prevent the leakage of package names, that is, through the measures at the file system level, the data and the package names under Android/data are directly isolated, and the process of each application can basically only be seen. A data directory belonging to its own uid.

 Check the following two props:

 ````
 getprop persist.zygote.app_data_isolation
 getprop persist.sys.vold_app_data_isolation_enabled


 ````

 If the return value is all 1, then congratulations, your system may have enabled data and Android/data isolation. It's not over though, because at this point it might not work as well as you think, let's explore the internal details in the source code:

 Take a look at Zygote first:

 ````
 // frameworks/base/core/java/com/android/internal/os/Zygote.java
     static int forkAndSpecialize(int uid, int gid, int[] gids, int runtimeFlags,
             int[][] rlimits, int mountExternal, String seInfo, String niceName, int[] fdsToClose,
             int[] fdsToIgnore, boolean startChildZygote, String instructionSet, String appDataDir,
             boolean isTopApp, String[] pkgDataInfoList, String[] allowlistedDataInfoList,
             boolean bindMountAppDataDirs, boolean bindMountAppStorageDirs)

 ````

 There are two parameters at the end `bindMountAppDataDirs`, `bindMountAppStorageDirs`, which seem to be related to these two directories, and `allowlistedDataInfoList` may be their whitelist.

 Trace all the way up to ProcessList.startProces, where we can see the origin of the parameters:

 ````
 // frameworks/base/services/core/java/com/android/server/am/ProcessList.java
             Map<String, Pair<String, Long>> pkgDataInfoMap;
             Map<String, Pair<String, Long>> allowlistedAppDataInfoMap;
             boolean bindMountAppStorageDirs = false;
             boolean bindMountAppsData = mAppDataIsolationEnabled
                     && (UserHandle.isApp(app.uid) || UserHandle.isIsolated(app.uid))
                     && mPlatformCompat.isChangeEnabled(APP_DATA_DIRECTORY_ISOLATION, app.info);

             // Get all packages belongs to the same shared uid. sharedPackages is empty array
             // if it doesn't have shared uid.
             final PackageManagerInternal pmInt = mService.getPackageManagerInternal();
             final String[] sharedPackages = pmInt.getSharedUserPackagesForPackage(
                     app.info.packageName, app.userId);
             final String[] targetPackagesList = sharedPackages.length == 0
                     ?new String[]{app.info.packageName} : sharedPackages;

             pkgDataInfoMap = getPackageAppDataInfoMap(pmInt, targetPackagesList, uid);
             if (pkgDataInfoMap == null) {
                 // TODO(b/152760674): Handle inode == 0 case properly, now we just give it a
                 // tmp free pass.
                 bindMountAppsData = false;
             }

             // Remove all packages in pkgDataInfoMap from mAppDataIsolationAllowlistedApps, so
             // it won't be mounted twice.
             final Set<String> allowlistedApps = new ArraySet<>(mAppDataIsolationAllowlistedApps);
             for (String pkg : targetPackagesList) {
                 allowlistedApps.remove(pkg);
             }

             allowlistedAppDataInfoMap = getPackageAppDataInfoMap(pmInt,
                     allowlistedApps.toArray(new String[0]), uid);
             if (allowlistedAppDataInfoMap == null) {
                 // TODO(b/152760674): Handle inode == 0 case properly, now we just give it a
                 // tmp free pass.
                 bindMountAppsData = false;
             }

             int userId = UserHandle.getUserId(uid);
             StorageManagerInternal storageManagerInternal = LocalServices.getService(
                     StorageManagerInternal.class);
             if (needsStorageDataIsolation(storageManagerInternal, app)) {
                 // We will run prepareStorageDirs() after we trigger zygote fork, so it won't
                 // slow down app starting speed as those dirs might not be cached.
                 if (pkgDataInfoMap != null && storageManagerInternal.isFuseMounted(userId)) {
                     bindMountAppStorageDirs = true;
                 } else {
                     // Fuse is not mounted or inode == 0,
                     // so we won't mount it in zygote, but resume the mount after unlocking device.
                     app.setBindMountPending(true);
                     bindMountAppStorageDirs = false;
                 }
             }

             // If it's an isolated process, it should not even mount its own app data directories,
             // since it has no access to them anyway.
             if (app.isolated) {
                 pkgDataInfoMap = null;
                 allowlistedAppDataInfoMap = null;
             }

                 startResult = Process.start(/* ... */,
                         allowlistedAppDataInfoMap, bindMountAppsData, bindMountAppStorageDirs,
                         new String[]{PROC_START_SEQ_IDENT + app.getStartSeq()});

 ````

 Among them bindMountAppStorageDirs is related to mVoldAppDataIsolationEnabled, bindMountAppsData is related to mAppDataIsolationEnabled ```
     private boolean needsStorageDataIsolation(StorageManagerInternal storageManagerInternal,
             ProcessRecord app) {
         final int mountMode = app.getMountMode();
         return mVoldAppDataIsolationEnabled && UserHandle.isApp(app.uid)
                 && !storageManagerInternal.isExternalStorageService(app.uid)
                 // Special mounting mode doesn't need to have data isolation as they won't
                 // access /mnt/user anyway.
                 && mountMode != Zygote.MOUNT_EXTERNAL_ANDROID_WRITABLE
                 && mountMode != Zygote.MOUNT_EXTERNAL_PASS_THROUGH
                 && mountMode != Zygote.MOUNT_EXTERNAL_INSTALLER
                 && mountMode != Zygote.MOUNT_EXTERNAL_NONE;
     }

         mAppDataIsolationEnabled =
                 SystemProperties.getBoolean(ANDROID_APP_DATA_ISOLATION_ENABLED_PROPERTY, true);
         mVoldAppDataIsolationEnabled = SystemProperties.getBoolean(
                 ANDROID_VOLD_APP_DATA_ISOLATION_ENABLED_PROPERTY, false);


 ````

 They are all related to system properties:

 ````
     // A system property to control if app data isolation is enabled.
     static final String ANDROID_APP_DATA_ISOLATION_ENABLED_PROPERTY =
             "persist.zygote.app_data_isolation";

     // A system property to control if obb app data isolation is enabled in vold.
     static final String ANDROID_VOLD_APP_DATA_ISOLATION_ENABLED_PROPERTY =
             "persist.sys.vold_app_data_isolation_enabled";

 ````

 So just set both of these properties to true? Let's try:

 ````
 setprop persist.zygote.app_data_isolation 1
 setprop persist.sys.vold_app_data_isolation_enabled 1


 ````

 The persist property can be retained after restart, so just setprop directly.

 After restarting, it can be observed that the isolation of Android/data takes effect, and the package name other than yourself under /sdcard/Android/data cannot be found through stat (stat corresponds to the package name path prompting that the file does not exist), but the file under /data/data seems to still be It does not take effect, but still get stat results. Three terminals were tested here: Terminal Emulator (API 22), JuiceSSH (API 29), MT Manager (API 26), and the results were consistent.

 Note that `bindMountAppsData` to be true also requires `mPlatformCompat.isChangeEnabled(APP_DATA_DIRECTORY_ISOLATION, app.info);` to be true. After tracing it can be found that the value here is actually taken from `/etc/compatconfig`.

 The detailed source code is here:

 ````
 frameworks/base/services/core/java/com/android/server/compat/PlatformCompat.java
 frameworks/base/services/core/java/com/android/server/compat/CompatConfig.java
 frameworks/base/services/core/java/com/android/server/compat/CompatChange.java


 ````

 APP_DATA_DIRECTORY_ISOLATION is a constant `143937733`, found in `/etc/compatconfig/services-platform-compat-config.xml`:

 ````
 <compat-change description="Apps have no access to the private data directories of any other app, even if the other app has made them world-readable." enableAfterTargetSdk="29" />


 ````

 It seems that API 29 or above (in Android 11, the method here is > 29) will perform data isolation, but we can use the Magisk module to modify this, that is, replace it with a file with `enableAfterTargetSdk="0"`.

 After this replacement, data isolation will be performed for any App of the target API.

 Finally, let's briefly study the principle of isolation, most of which are implemented in zygote using bind mount.

 `frameworks/base/core/jni/com_android_internal_os_Zygote.cpp`

 Data isolation is actually to mount a layer of tmpfs to /data/data, then create the required directory on it, and bind and mount the original app data directory.

 However, some people will ask, since /data/data has been hung with a layer of tmpfs, you can't see the data directory inside, how can you bind and mount these directories?

 So Android 11 has an additional /data_mirror directory in the root directory, `/data_mirror/cur_profiles`, which is the mirror mount of /data/data. The permission of this directory is 700, and the owner is root, so the App cannot detect the existence of the package name through this, and zygote can find the original data directory from here and perform bind mount.

 In fact, the process is quite complicated. For the specific implementation, please refer to the function isolateAppData in the source code, except that /data/data is a traditional CE (credential encryption) storage directory to be isolated, and /data/user multi-user data directory, /data/ user_de device encrypted storage directory, /mnt/expand extended storage directory. And for CE storage, it is also necessary to consider that the boot is in an encrypted state, and the directory needs to be searched by inode instead of path name. There's even an isolateJitProfile function, which handles leaking package names under `/data/misc/profiles/cur`. It seems that Android is far more thoughtful in this regard than we think.

 Similarly, the Android/data directory is also isolated by bind mount, and the function BindMountStorageDirs does this work.

 However, it should be noted that different mount_external types will mount different directories under /mnt to /storage, and some of these directories bind mount the original directory under /data/media to the Android/data directory (such as /mnt/ androidwritable), some do not (such as /mnt/installer), in this case, bind mount will not be enabled to isolate Android/data, but it can still have the effect of isolation. It is presumed that at this time, Android/data is accessed through fuse, and the isolation is handled by fuse. In this case, you can see the contents of Android/data after su. 
