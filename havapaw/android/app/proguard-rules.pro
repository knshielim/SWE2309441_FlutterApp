# TensorFlow Lite (tflite_flutter): the GPU delegate classes are optional and are not
# included in the app, so R8 must not fail on references to them.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.GpuDelegate
-dontwarn org.tensorflow.lite.gpu.**

# Keep the TFLite Java classes that its native (JNI) code looks up by name.
-keep class org.tensorflow.lite.** { *; }
