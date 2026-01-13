# Razorpay keep rules
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Some versions reference proguard.annotation.Keep*; keep/dontwarn to avoid class not found during shrink
-keep class proguard.annotation.** { *; }
-dontwarn proguard.annotation.**

# Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep annotations
-keepattributes *Annotation*

