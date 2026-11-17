# libvlcjni.so looks up LibVLC's Java classes, fields and methods by name in
# JNI_OnLoad. If R8 renames or removes them, JNI_OnLoad fails and LibVLC
# calls System.exit(1), so the release app quits as soon as it starts.
-keep class org.videolan.libvlc.** { *; }
-keep interface org.videolan.libvlc.** { *; }
-dontwarn org.videolan.libvlc.**
