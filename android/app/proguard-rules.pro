# Flutter and most of this app's plugins (supabase_flutter, image_picker,
# flutter_image_compress, flutter_secure_storage) are invoked through
# generated MethodChannel/Pigeon code, not runtime reflection, so R8's
# default shrinking doesn't need special keep rules for them.
#
# doc_scan_flutter is the exception: it wraps Google Play Services'
# play-services-mlkit-document-scanner, whose scanning UI is a Play Core
# dynamic-delivery module loaded via reflection at runtime. Without these
# keep rules, R8 strips classes that module needs and the scanner fails to
# open in release builds (this broke camera scanning after minification
# was turned on — verified fix, do not remove).
-keep class com.google.android.gms.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.play.core.**
