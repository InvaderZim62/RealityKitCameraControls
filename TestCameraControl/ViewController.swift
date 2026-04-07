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
    var cameraOffset = simd_float3(0, 0, 10)  // position in camera coordinates
    var camerRotation: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.cameraMode = .nonAR
        arView.debugOptions = [.showWorldOrigin, .showPhysics]  // use .showPhysics with .generateCollisionShapes
        arView.environment.background = .color(.lightGray)
        arView.scene.addAnchor(worldAnchor)

        camera.position = cameraOffset
        worldAnchor.addChild(camera)

        let material = SimpleMaterial(color: .gray, isMetallic: false)
        let box = ModelEntity(mesh: .generateBox(size: [1, 1, 1]))
        box.model?.materials = [material]
        box.position = [0, 0, 0]
        box.generateCollisionShapes(recursive: false)  // use with debugOptions
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

            // deltaRight rotates the scene/camera about the world y-axis;
            // deltaUp rotates the scene/camera about the camera x-axis;
            // deltaRight must be converted to camera coordinates before adding to deltaUp
            let deltaCamera = convertVectorFromWorldToLocal(vector: simd_float3(0, -deltaRight, 0), camera.orientation)
            camera.orientation = camera.orientation.rotatedBy(deltaPitch: deltaUp + deltaCamera.x, deltaYaw: deltaCamera.y, deltaRoll: deltaCamera.z)

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
        camera.orientation = camera.orientation.rotatedBy(deltaPitch: 0, deltaYaw: 0, deltaRoll: deltaRoll)
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

extension simd_quatf {
    
    // incrementally rotate quaternion
    func rotatedBy(deltaPitch: Float, deltaYaw: Float, deltaRoll: Float) -> simd_quatf {
        let quat = self.vector
        
        // quaternion rates (aeronautical standard, except: p -> q, q -> r, r -> p)
        let deltaQw = (-quat.x * deltaPitch - quat.y * deltaYaw - quat.z * deltaRoll) / 2
        let deltaQx = ( quat.w * deltaPitch - quat.z * deltaYaw + quat.y * deltaRoll) / 2
        let deltaQy = ( quat.z * deltaPitch + quat.w * deltaYaw - quat.x * deltaRoll) / 2
        let deltaQz = (-quat.y * deltaPitch + quat.x * deltaYaw + quat.w * deltaRoll) / 2
        
        // increment quaternion rates
        let qw = quat.w + deltaQw
        let qx = quat.x + deltaQx
        let qy = quat.y + deltaQy
        let qz = quat.z + deltaQz
        
        // normalize quaternions to prevent error growth
        return simd_normalize(simd_quatf(ix: qx, iy: qy, iz: qz, r: qw))
    }
}
