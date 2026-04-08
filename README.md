# RealityKit Camera Controls

Apple deprecated SceneKit, so I started to learn about RealityKit.  Even though RealityKit was designed for
augmented reality, it can be used to create virtual 3D environments without the camera (by setting
arView.CameraMode = .nonAR).  I quickly learned however, it doesn't include an equivalent .allowsCameraControl
capability.  While this was added to SwiftUI (using .realityViewCameraControls(CameraControls.orbit)), it still
isn't available in Swift, so I figured out how to do it myself.

An important part of the code is a method called rotatedBy, which incrementally rotates the camera quaternion
using pan gestures.  This allows smooth rotation past vertical, without any discontinuities or singularities.

Here is what the virtual camera control does for each gesture:

| Gesture | Fingers | Camera Action |
| ------- | :-----: | ------------- |
| Horizontal Pan | 1 | Rotate about world y-axis |
| Vertical Pan | 1 | Rotate about camera x-axis |
| Pan | 2 | Move in camera x/y plane |
| Pinch | 2 | Move forward/aft (along camera z-axis) |
| Rotation | 2 | Rotate about camera z-axis |

It's important to note, the 1-finger horizontal and vertical pans rotate in different coordinate systems.  The
horizontal pan (world axes) must be converted to camera axes, then added to the vertical pan (camera axes),
before applying to the camera rotation.
