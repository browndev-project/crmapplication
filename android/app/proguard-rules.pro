# Paytm All-in-One SDK ProGuard Rules
-keep class com.paytm.pgsdk.** { *; }
-keep class com.paytm.pgsdk.model.ProcessTransactionInfo { *; }
-keep class com.paytm.pgsdk.model.Body { *; }
-keep class easypay.appinvoke.** { *; }
-keep class net.one97.paytm.** { *; }
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes *Annotation*
-dontwarn com.paytm.pgsdk.**
-dontwarn easypay.appinvoke.**
