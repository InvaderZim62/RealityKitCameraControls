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

import UIKit
import RealityKit
import ARKit

struct Constant {
    static let cameraDistance: Float = 5  // can't be at 0, for pinch to work
}

class ViewController: UIViewController {

    @IBOutlet weak var arView: ARView!
    
    let worldAnchor = AnchorEntity()
    let camera = PerspectiveCamera()
    var cameraDistance: Float = Constant.cameraDistance

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

        let floorMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let redFloor = ModelEntity(mesh: .generateBox(size: [2, 0.1, 2]))
        redFloor.model?.materials = [floorMaterial]
        redFloor.position = [0, -1, 0]
        worldAnchor.addChild(redFloor)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        arView.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        arView.addGestureRecognizer(pinch)
    }
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            cameraDistance = sqrt(pow(camera.position.x, 2) + pow(camera.position.y, 2) + pow(camera.position.z, 2))
        case .changed:
            let translate = recognizer.translation(in: recognizer.view)
            let deltaUp = Float(translate.y / 200)
            let deltaRight = Float(translate.x / 100)
            recognizer.setTranslation(.zero, in: recognizer.view)

            let camereEulers = camera.transform.matrix.eulerAngles  // [x, y, z], pitch, -yaw, -roll
            print(String(format: "camera.eulerAngles: (x: %0.2f, y: %0.2f, z: %0.2f)", camereEulers.x * 57.3, camereEulers.y * 57.3, camereEulers.z * 57.3))
            
//            // move the camera around the center
//            camera.position = [-cameraDistance * sin(yaw),
//                                cameraDistance * sin(pitch),
//                                cameraDistance * cos(pitch) * cos(yaw)]

            let p = deltaRight * sin(camereEulers.x)  // roll about camera z
            let q = -deltaUp  // pitch about camera x
            let r = -deltaRight * cos(camereEulers.x)  // yaw about camera y
            
            let quatIC = camera.orientation.vector  // [x, y, z, w], where w is the rotation
            
            // quaternion rates
            let qwDot = (-quatIC.x * q - quatIC.y * r - quatIC.z * p) / 2
            let qxDot = ( quatIC.w * q - quatIC.z * r + quatIC.y * p) / 2
            let qyDot = ( quatIC.z * q + quatIC.w * r - quatIC.x * p) / 2
            let qzDot = (-quatIC.y * q + quatIC.x * r + quatIC.w * p) / 2
            
            // intergate
            var qw = quatIC.w + qwDot
            var qx = quatIC.x + qxDot
            var qy = quatIC.y + qyDot
            var qz = quatIC.z + qzDot
            
            // normalize to prevent error growth (probably not needed)
            let qnorm = sqrt(pow(qw, 2) + pow(qx, 2) + pow(qy, 2) + pow(qz, 2))
            
            qw /= qnorm
            qx /= qnorm
            qy /= qnorm
            qz /= qnorm
            
            camera.orientation = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
            
            let eulerAngles = camera.transform.matrix.eulerAngles  // [x, y, z], pitch, -yaw, -roll
            
            // move the camera around the center
            camera.position = [ cameraDistance * cos(eulerAngles.x) * sin(eulerAngles.y),
                               -cameraDistance * sin(eulerAngles.x),
                                cameraDistance * cos(eulerAngles.x) * cos(eulerAngles.y)]
        default: return
        }
    }

    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            camera.position.x *= 1 / Float(recognizer.scale)
            camera.position.y *= 1 / Float(recognizer.scale)
            camera.position.z *= 1 / Float(recognizer.scale)
            recognizer.scale = 1
        default: break
        }
    }
    
    // direction cosine matrix
    public func eul2rot(theta: simd_float3) -> simd_float3x3 {
        var R = simd_float3x3(columns: (
            [cos(theta[1])*cos(theta[2]),
             sin(theta[0])*sin(theta[1])*cos(theta[2]) - sin(theta[2])*cos(theta[0]),
             sin(theta[1])*cos(theta[0])*cos(theta[2]) + sin(theta[0])*sin(theta[2])],
            [sin(theta[2])*cos(theta[1]),
             sin(theta[0])*sin(theta[1])*sin(theta[2]) + cos(theta[0])*cos(theta[2]),
             sin(theta[1])*sin(theta[2])*cos(theta[0]) - sin(theta[0])*cos(theta[2])],
            [-sin(theta[1]),
              sin(theta[0])*cos(theta[1]),
              cos(theta[0])*cos(theta[1])]))
        R = R.transpose
        return R
    }
}

extension simd_float4x4 {
    var eulerAngles: simd_float3 {
        simd_float3(
            x: asin(-self[2][1]),
            y: atan2(self[2][0], self[2][2]),
            z: atan2(self[0][1], self[1][1])
        )
    }
}
