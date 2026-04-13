# RealityKit Camera Controls

Apple deprecated SceneKit, so I started to learn about RealityKit.  Even though RealityKit was designed for
augmented reality, it can be used to create virtual 3D environments without the camera (by setting
arView.CameraMode = .nonAR).  I quickly learned however, it doesn't include an equivalent .allowsCameraControl
capability.  While this was added to SwiftUI (using .realityViewCameraControls(CameraControls.orbit)), it still
isn't available in Swift, so I figured out how to do it myself.

An important part of my code is a method called rotatedBy, which incrementally rotates the camera quaternion
using pan gestures.  This allows smooth rotation past vertical, without any discontinuities or singularities.

Here is what the virtual camera control does for each gesture:

| Gesture | Fingers | Camera Action |
| ------- | :-----: | ------------- |
| Horizontal Pan | 1 | Rotate about world y-axis |
| Vertical Pan | 1 | Rotate about camera x-axis |
| Pan | 2 | Move along camera x/y axes |
| Pinch | 2 | Move along camera z-axis |
| Rotation | 2 | Rotate about camera z-axis |

It's important to note, the 1-finger horizontal and vertical pans rotate in different coordinate systems.  The
horizontal pan (world axes) must be converted to camera axes, then added to the vertical pan (camera axes),
before applying to the camera rotation.

Here's a side-by-side comparison of several gesture in SceneKit and RealiyKit, using this code:

| ![Camera Control SceneKit](https://github.com/user-attachments/assets/aec5bbe3-b9db-445f-9d3b-e26afd2a3d99) | ![Camera Contol RealityKit](https://github.com/user-attachments/assets/b5d59ba2-f427-45df-b53e-3fc0eb99e786) |
| :---: | :---: |
| SceneKit | RealityKit |
