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

import UIKit
import RealityKit
import ARKit

struct Constant {
    static let cameraDistance: Float = 4  // can't be at 0, for pinch to work
}

class ViewController: UIViewController {

    @IBOutlet weak var arView: ARView!
    
    let worldAnchor = AnchorEntity()
    let camera = PerspectiveCamera()
    var offsetPoint = ModelEntity()  // pws: eventually replace this with simd_float3.zero
    var cameraDistance: Float = Constant.cameraDistance

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.cameraMode = .nonAR
        arView.debugOptions = [.showWorldOrigin, .showPhysics]  // use .showPhysics with .generateCollisionShapes
        arView.environment.background = .color(.lightGray)
        arView.scene.addAnchor(worldAnchor)

        camera.position.z = Constant.cameraDistance
        worldAnchor.addChild(camera)

        // greenCube is always aligned with world coordinates, since I'm only manipulating the camera
        let cubeMaterial = SimpleMaterial(color: .green, isMetallic: false)
        let greenCube = ModelEntity(mesh: .generateBox(size: [0.2, 0.2, 0.2]))
        greenCube.model?.materials = [cubeMaterial]
        greenCube.position = [0, 0, 0]
        greenCube.generateCollisionShapes(recursive: false)  // use with debugOptions
        worldAnchor.addChild(greenCube)

        // offsetPoint shows the accumulated translating/strafing of the camera
        let pointMaterial = SimpleMaterial(color: .lightGray, isMetallic: false)
        offsetPoint = ModelEntity(mesh: .generateBox(size: [0.1, 0.1, 0.1]))
        offsetPoint.model?.materials = [pointMaterial]
        offsetPoint.position = [0, 0, 0]
        offsetPoint.generateCollisionShapes(recursive: false)  // use with debugOptions
        worldAnchor.addChild(offsetPoint)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        arView.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        arView.addGestureRecognizer(pinch)
    }
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            print(String(format: "began - camera.position: %.2f, %.2f, %.2f", camera.position.x, camera.position.y, camera.position.z))
        case .changed:
            if recognizer.numberOfTouches == 1 {
                // rotate camera
                let translation = recognizer.translation(in: recognizer.view)
                let deltaUp = Float(-translation.y / 200)
                let deltaRight = Float(translation.x / 100)
                recognizer.setTranslation(.zero, in: recognizer.view)
                
                // Xcode definitions:
                //   euler.x = pitch angle (pos. about x-axis, nose up)
                //   euler.y = yaw angle (pos. about y-axis, nose left)
                //   euler.z = bank angle (pos. about z-axis, bank left)
                let cameraEulers = camera.transform.matrix.eulerAngles
                
                let deltaPitch = deltaUp
                var deltaYaw = -deltaRight * cos(cameraEulers.x)
                let deltaRoll = deltaRight * sin(cameraEulers.x)
                if abs(cameraEulers.z) > .pi / 2 {
                    deltaYaw *= -1  // bug fix? when past vertical
                }
                
                camera.orientation = camera.orientation.rotatedBy(deltaPitch: deltaPitch, deltaYaw: deltaYaw, deltaRoll: deltaRoll)

                // convert vector out back of camera (plus offset) to world coordinates, and place camera there
                camera.position = transformVectorToWorld(offsetPoint.position + simd_float3(0, 0, cameraDistance), camera.transform.matrix)  // rotates about world origin (good)
//                camera.position = transformVectorToWorld(simd_float3(0, 0, cameraDistance), camera.transform.matrix) + offsetPoint.position  // rotates about offsetPoint (bad)
                
               print(String(format: "rotated - camera.position: %.2f, %.2f, %.2f", camera.position.x, camera.position.y, camera.position.z))
            } else if recognizer.numberOfTouches == 2 {
                // strafe camera
                let translation = recognizer.translation(in: recognizer.view)
                recognizer.setTranslation(.zero, in: recognizer.view)
                let deltaBody = simd_float3(Float(translation.x), Float(-translation.y), 0) / 100
                let deltaWorld = transformVectorToWorld(deltaBody, camera.transform.matrix)
                offsetPoint.position -= deltaWorld

                camera.position -= deltaWorld  // always works, but discontinuity on first pass of rotation (same reason why next line doesn't work well)
//                camera.position = transformVectorToWorld(offsetPoint.position + simd_float3(0, 0, cameraDistance), camera.transform.matrix)  // off-axes don't work (bad)
//                camera.position = transformVectorToWorld(simd_float3(0, 0, cameraDistance), camera.transform.matrix) + offsetPoint.position  // moves camera with offsetPoint (good)
                
                print(String(format: "strafed - deltaBody: %.4f, %.4f, %.4f", deltaBody.x, deltaBody.y, deltaBody.z))
                print(String(format: "strafed - deltaWorld: %.4f, %.4f, %.4f", deltaWorld.x, deltaWorld.y, deltaWorld.z))
                print(String(format: "strafed - offsetPoint.position: %.2f, %.2f, %.2f", offsetPoint.position.x, offsetPoint.position.y, offsetPoint.position.z))
                print(String(format: "strafed - camera.position: %.2f, %.2f, %.2f", camera.position.x, camera.position.y, camera.position.z))
                print()
            }
        case .ended:
            print(String(format: "ended - camera.position: %.2f, %.2f, %.2f", camera.position.x, camera.position.y, camera.position.z))
        default:
            return
        }
    }

    // pinching moves camera forwards/aft (ie. camera z-direction)
    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) {
//        var offsetPointToCamera = camera.position - offsetPoint.position
//        offsetPointToCamera /= Float(recognizer.scale)
//        camera.position = offsetPoint.position + offsetPointToCamera
//        cameraDistance /= Float(recognizer.scale)
        
        // these always work
        cameraDistance /= Float(recognizer.scale)
        camera.position = transformVectorToWorld(offsetPoint.position + simd_float3(0, 0, cameraDistance), camera.transform.matrix)

        recognizer.scale = 1
    }
    
    // transform vector from body to world
    public func transformVectorToWorld(_ vector: simd_float3, _ transform: simd_float4x4) -> simd_float3 {
        let quat = simd_quatf(transform).vector  // simd_float4 (x, y, z, w)
        
        let t0 = -quat.x * vector.x - quat.y * vector.y - quat.z * vector.z
        let t1 =  quat.w * vector.x + quat.y * vector.z - quat.z * vector.y
        let t2 =  quat.w * vector.y - quat.x * vector.z + quat.z * vector.x
        let t3 =  quat.w * vector.z + quat.x * vector.y - quat.y * vector.x
        
        let v1 = -t0 * quat.x + t1 * quat.w - t2 * quat.z + t3 * quat.y
        let v2 = -t0 * quat.y + t1 * quat.z + t2 * quat.w - t3 * quat.x
        let v3 = -t0 * quat.z - t1 * quat.y + t2 * quat.x + t3 * quat.w
        
        return simd_float3(v1, v2, v3)
    }
    
    // transform vector from world to body
    public func transformVectorToBody(_ vector: simd_float3, _ transform: simd_float4x4) -> simd_float3 {
        let quat = simd_quatf(transform).vector  // simd_float4 (x, y, z, w)
        
        let t0 = quat.x * vector.x + quat.y * vector.y + quat.z * vector.z
        let t1 = quat.w * vector.x - quat.y * vector.z + quat.z * vector.y
        let t2 = quat.w * vector.y + quat.x * vector.z - quat.z * vector.x
        let t3 = quat.w * vector.z - quat.x * vector.y + quat.y * vector.x
        
        let v1 = t0 * quat.x + t1 * quat.w + t2 * quat.z - t3 * quat.y
        let v2 = t0 * quat.y - t1 * quat.z + t2 * quat.w + t3 * quat.x
        let v3 = t0 * quat.z + t1 * quat.y - t2 * quat.x + t3 * quat.w
        
        return simd_float3(v1, v2, v3)
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

extension PerspectiveCamera {
    var eulerAngles: simd_float3 {
        simd_float3(
            x: asin(-self.transform.matrix[2][1]),
            y: atan2(self.transform.matrix[2][0], self.transform.matrix[2][2]),
            z: atan2(self.transform.matrix[0][1], self.transform.matrix[1][1])
        )
    }
    var eulerAnglesDegrees: simd_float3 {
        simd_float3(
            x: asin(-self.transform.matrix[2][1]) * 180 / .pi,
            y: atan2(self.transform.matrix[2][0], self.transform.matrix[2][2]) * 180 / .pi,
            z: atan2(self.transform.matrix[0][1], self.transform.matrix[1][1] * 180 / .pi)
        )
    }
}

extension ModelEntity {
    var eulerAngles: simd_float3 {
        simd_float3(
            x: asin(-self.transform.matrix[2][1]),
            y: atan2(self.transform.matrix[2][0], self.transform.matrix[2][2]),
            z: atan2(self.transform.matrix[0][1], self.transform.matrix[1][1])
        )
    }
    var eulerAnglesDegrees: simd_float3 {
        simd_float3(
            x: asin(-self.transform.matrix[2][1]) * 180 / .pi,
            y: atan2(self.transform.matrix[2][0], self.transform.matrix[2][2]) * 180 / .pi,
            z: atan2(self.transform.matrix[0][1], self.transform.matrix[1][1] * 180 / .pi)
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
        var qw = quat.w + deltaQw
        var qx = quat.x + deltaQx
        var qy = quat.y + deltaQy
        var qz = quat.z + deltaQz
        
        // normalize quaternions to prevent integration error growth
        let qnorm = sqrt(pow(qw, 2) + pow(qx, 2) + pow(qy, 2) + pow(qz, 2))
        
        qw /= qnorm
        qx /= qnorm
        qy /= qnorm
        qz /= qnorm
        
        return simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
    }
}
