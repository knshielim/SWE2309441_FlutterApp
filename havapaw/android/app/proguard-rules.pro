# TensorFlow Lite: the optional GPU delegate is not used by the app
-dontwarn org.tensorflow.lite.gpu.**
# Keep TensorFlow Lite classes used through JNI
-keep class org.tensorflow.lite.** { *; }
