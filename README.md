# RealityKit Camera Controls

Apple deprecated SceneKit, so I started to learn about RealityKit.  Even though RealityKit was designed for
augmented reality, it can be used to create virtual 3D environments without the camera (by setting
arView.CameraMode = .nonAR).  I quickly learned however, it doesn't include an equivalent `.allowsCameraControl`
capability.  While this was added to SwiftUI (using `.realityViewCameraControls(CameraControls.orbit)`), it still
isn't available in Swift, so I figured out how to do it myself.

An important part of the code is this line: `camera.setTransformMatrix(transform.matrix, relativeTo: camera)`,
which is used to incrementally rotate the camera using gestures.  This allows smooth rotation past vertical,
without any discontinuities or singularities.

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

Here's a side-by-side comparison of several gesture in SceneKit with built-in camera controls, and RealityKit,
using my code:

| ![Camera Control SceneKit](https://github.com/user-attachments/assets/aec5bbe3-b9db-445f-9d3b-e26afd2a3d99) | ![Camera Contol RealityKit](https://github.com/user-attachments/assets/b5d59ba2-f427-45df-b53e-3fc0eb99e786) |
| :---: | :---: |
| SceneKit | RealityKit |

Here is what the camera is doing with the same gestures as above.  It was created using another one of my apps
called [TwoCameras](https://github.com/InvaderZim62/TwoCameras).

![Two cameras](https://github.com/user-attachments/assets/8662b47f-5f0d-415d-a890-0eb833332b98)
