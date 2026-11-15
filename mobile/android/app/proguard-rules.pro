# WebRTC (calls and rooms) is called from native code
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**
