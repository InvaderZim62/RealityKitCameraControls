# RealityKit Camera Controls

Apple deprecated SceneKit, so I started to learn about RealityKit.  Even though RealityKit was designed for
augmented reality, it can be used to create virtual 3D environments without the camera, like SceneKit (by setting
arView.CameraMode = .nonAR).  I quickly learned however, it doesn't include an equivalent .allowsCameraControl
capability.  While this was added for SwiftUI (using .realityViewCameraControls(CameraControls.orbit)), it still
isn't available in Swift, so I figured out how to do it myself.

An important part of the code is a method called rotatedBy, which incrementally rotates the camera quaternion
using pan gestures.  This allows smooth rotation past vertical, without any discontinuities or singularities.

Here is what the virtual camera control does for each gesture:

TBD...
