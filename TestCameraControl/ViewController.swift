//
//  ViewController.swift
//  TestCameraControl
//
//  Created by Phil Stern on 3/20/26.
//
//  Test of my version of pan and pinch.
//
//  Useful properties:
//    let eulerAngles = camera.transform.matrix.eulerAngles  // [x, y, z], pitch, -yaw, -roll
//    let quaternion = simd_quatf(camera.transform.matrix).vector  // [x, y, z, w], where w is the rotation
//    -or-
//    let quaternion = camera.orientation.vector
//
//  Useful methods:
//    simd_mul(simd_float3, simd_float3x3)  // vector times matrix
//    simd_mul(simd_float4, simd_float4x4)  // "
//
//  These do the same thing:
//    camera.position += deltaBody
//    camera.transform.translation += deltaBody
//
//  Xcode definitions:
//    euler.x = pitch angle (pos. nose up)
//    euler.y = yaw angle   (pos. nose left)
//    euler.z = bank angle  (pos. bank left)
//

import UIKit
import RealityKit

class ViewController: UIViewController {

    @IBOutlet weak var arView: ARView!
    
    let worldAnchor = AnchorEntity()
    let camera = PerspectiveCamera()
    var cameraOffset = simd_float3(0, 0, 10)  // camera position in camera coordinates

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.cameraMode = .nonAR
        arView.debugOptions = [.showWorldOrigin, .showPhysics]  // show axes (requires .generateCollisionShapes)
        arView.environment.background = .color(.lightGray)
        arView.scene.addAnchor(worldAnchor)

        camera.position = cameraOffset
        worldAnchor.addChild(camera)

        let material = SimpleMaterial(color: .gray, isMetallic: false)
        let box = ModelEntity(mesh: .generateBox(size: [1, 1, 1]))
        box.model?.materials = [material]
        box.position = [0, 0, 0]
        box.generateCollisionShapes(recursive: false)  // needed for debugOptions
        worldAnchor.addChild(box)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        arView.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        arView.addGestureRecognizer(pinch)
        
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        arView.addGestureRecognizer(rotation)
    }
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        
        if recognizer.numberOfTouches == 1 {
            // rotate camera
            let deltaRight = Float(translation.x / 130)
            let deltaUp = Float(-translation.y / 130)

            // deltaRight rotates the scene/camera about the world neg. y-axis;
            // deltaUp rotates the scene/camera about the camera pos. x-axis;
            // deltaRight must be converted to camera coordinates before adding to deltaUp
            let deltaCamera = convertVectorFromWorldToLocal(vector: simd_float3(0, -deltaRight, 0), camera.orientation)
            
            let transform = Transform(pitch: deltaCamera.x + deltaUp,
                                      yaw: deltaCamera.y,
                                      roll: deltaCamera.z)
            camera.setTransformMatrix(transform.matrix, relativeTo: camera)  // incremental rotation

        } else if recognizer.numberOfTouches == 2 {
            // offset camera
            let deltaRight = Float(translation.x / 75)
            let deltaUp = Float(-translation.y / 75)

            // deltas move the scene/camera in camera coordinates
            let deltaPosition = simd_float3(deltaRight, deltaUp, 0)
            cameraOffset -= deltaPosition
        }
        
        camera.position = convertVectorFromLocalToWorld(vector: cameraOffset, camera.orientation)
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) {
        // pinching moves the camera forward/aft (ie. camera z-direction)
        cameraOffset.z /= Float(recognizer.scale)
        camera.position = convertVectorFromLocalToWorld(vector: cameraOffset, camera.orientation)
        recognizer.scale = 1
    }
    
    @objc func handleRotation(recognizer: UIRotationGestureRecognizer) {
        // rotation rotates the scene/camera about the camera z-axis (ie. center of screen)
        let deltaRoll = Float(recognizer.rotation)
        let transform = Transform(pitch: 0, yaw: 0, roll: deltaRoll)
        camera.setTransformMatrix(transform.matrix, relativeTo: camera)  // incremental rotation
        let deltaQuat = simd_quatf(angle: deltaRoll, axis: [0, 0, 1])
        cameraOffset = convertVectorFromWorldToLocal(vector: cameraOffset, deltaQuat)
        recognizer.rotation = 0
    }
    
    private func convertVectorFromLocalToWorld(vector: simd_float3, _ quat: simd_quatf) -> simd_float3 {
        quat.act(vector)
    }
    
    private func convertVectorFromWorldToLocal(vector: simd_float3, _ quat: simd_quatf) -> simd_float3 {
        quat.inverse.act(vector)
    }
}
