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

struct Constant {
    static let cameraDistance: Float = 4  // can't be at 0, for pinch to work
}

class ViewController: UIViewController {

    @IBOutlet weak var arView: ARView!
    
    let worldAnchor = AnchorEntity()
    let camera = PerspectiveCamera()
    var cameraOffset = simd_float3(0, 0, Constant.cameraDistance)
    var camerRotation: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.cameraMode = .nonAR
        arView.debugOptions = [.showWorldOrigin, .showPhysics]  // use .showPhysics with .generateCollisionShapes
        arView.environment.background = .color(.lightGray)
        arView.scene.addAnchor(worldAnchor)

        camera.position.z = Constant.cameraDistance
        worldAnchor.addChild(camera)

        let cubeMaterial = SimpleMaterial(color: .green, isMetallic: false)
        let greenCube = ModelEntity(mesh: .generateBox(size: [0.2, 0.2, 0.2]))
        greenCube.model?.materials = [cubeMaterial]
        greenCube.position = [0, 0, 0]
        greenCube.generateCollisionShapes(recursive: false)  // use with debugOptions
        worldAnchor.addChild(greenCube)

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
            let deltaUp = Float(-translation.y / 150)
            let deltaRight = Float(translation.x / 150)

            //  Xcode definitions:
            //    euler.x = pitch angle (pos. nose up)
            //    euler.y = yaw angle   (pos. nose left)
            //    euler.z = bank angle  (pos. bank left)

            print()
            let cameraEulers = camera.transform.matrix.eulerAngles
            prettyPrint(eulers: cameraEulers)

            // pan right: rotate world around world y-axis (rotate camera about negative world y-axis)
            // pan up: rotate world about screen left-axis (rotate camera about positive camera x-axis)
            let deltaCamera = transformVectorToBody(simd_float3(0, -deltaRight, 0), camera.orientation.vector)
            camera.orientation = camera.orientation.rotatedBy(deltaPitch: deltaUp + deltaCamera.x, deltaYaw: deltaCamera.y, deltaRoll: deltaCamera.z)

        } else if recognizer.numberOfTouches == 2 {
            // offset camera
            let deltaPosition = simd_float3(Float(translation.x), Float(-translation.y), 0) / 180
            cameraOffset -= deltaPosition
        }
        
        camera.position = transformVectorToWorld(cameraOffset, camera.orientation.vector)
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    // pinching moves camera forwards/aft (ie. camera z-direction)
    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) {
        cameraOffset.z /= Float(recognizer.scale)
        camera.position = transformVectorToWorld(cameraOffset, camera.orientation.vector)
        recognizer.scale = 1
    }
    
    @objc func handleRotation(recognizer: UIRotationGestureRecognizer) {
        // rotate clockwise: rotate about screen negative z-axis (camera roll)
        let deltaRoll = Float(recognizer.rotation)
        camera.orientation = camera.orientation.rotatedBy(deltaPitch: 0, deltaYaw: 0, deltaRoll: deltaRoll)
        let deltaQuat = simd_quatf(angle: deltaRoll, axis: [0, 0, 1])  // this works for strafing, but not pan-rotating
        cameraOffset = transformVectorToBody(cameraOffset, deltaQuat.vector)
        recognizer.rotation = 0
        print()
        let cameraEulers = camera.transform.matrix.eulerAngles
        prettyPrint(eulers: cameraEulers)
    }
    
    // transform vector from body to world coordinates
    public func transformVectorToWorld(_ vector: simd_float3, _ quat: simd_float4) -> simd_float3 {
//        let quat = simd_quatf(transform).vector  // simd_float4 (x, y, z, w)
        
        let t0 = -quat.x * vector.x - quat.y * vector.y - quat.z * vector.z
        let t1 =  quat.w * vector.x + quat.y * vector.z - quat.z * vector.y
        let t2 =  quat.w * vector.y - quat.x * vector.z + quat.z * vector.x
        let t3 =  quat.w * vector.z + quat.x * vector.y - quat.y * vector.x
        
        let v1 = -t0 * quat.x + t1 * quat.w - t2 * quat.z + t3 * quat.y
        let v2 = -t0 * quat.y + t1 * quat.z + t2 * quat.w - t3 * quat.x
        let v3 = -t0 * quat.z - t1 * quat.y + t2 * quat.x + t3 * quat.w
        
        return simd_float3(v1, v2, v3)
    }
    
    // transform vector from world to body coordinates
    private func transformVectorToBody(_ vector: simd_float3, _ quat: simd_float4) -> simd_float3 {
        let t0 = quat.x * vector.x + quat.y * vector.y + quat.z * vector.z
        let t1 = quat.w * vector.x - quat.y * vector.z + quat.z * vector.y
        let t2 = quat.w * vector.y + quat.x * vector.z - quat.z * vector.x
        let t3 = quat.w * vector.z - quat.x * vector.y + quat.y * vector.x
        
        let v1 = t0 * quat.x + t1 * quat.w + t2 * quat.z - t3 * quat.y
        let v2 = t0 * quat.y - t1 * quat.z + t2 * quat.w + t3 * quat.x
        let v3 = t0 * quat.z + t1 * quat.y - t2 * quat.x + t3 * quat.w
        
        return simd_float3(v1, v2, v3)
    }
    
    func prettyPrint(eulers: simd_float3) {  // in degrees
        print(String(format: "Eulers: pitch: %.1f, yaw: %.1f, roll: %.1f", eulers.x * 180 / .pi, eulers.y * 180 / .pi, eulers.z * 180 / .pi))
    }
}

extension simd_float3 {
    var magnitude: Float {
        sqrt(x * x + y * y + z * z)
    }
}

extension simd_float4x4 {
    // extract Euler angles from transform matrix
    var eulerAngles: simd_float3 {
        simd_float3(
            x: asin(-self[2][1]),
            y: atan2(self[2][0], self[2][2]),
            z: atan2(self[0][1], self[1][1])
        )
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
        
        // intergate quaternion rates
        let qw = quat.w + deltaQw
        let qx = quat.x + deltaQx
        let qy = quat.y + deltaQy
        let qz = quat.z + deltaQz
        
        // normalize quaternions to prevent integration error growth
        return simd_normalize(simd_quatf(ix: qx, iy: qy, iz: qz, r: qw))
    }
}
