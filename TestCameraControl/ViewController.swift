//
//  ViewController.swift
//  TestCameraControl
//
//  Created by Phil Stern on 3/20/26.
//

import UIKit
import RealityKit

class ViewController: UIViewController {

    @IBOutlet weak var arView: ARView!
    
    let worldAnchor = AnchorEntity()
    let camera = PerspectiveCamera()
    var pitch: Float = 0.0
    var yaw: Float = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.lightGray)
        arView.scene.addAnchor(worldAnchor)

        camera.position.z = 5  // can't be at 0, for pinch to work
        icPosition = camera.position
        worldAnchor.addChild(camera)

        let material1 = SimpleMaterial(color: .green, isMetallic: false)
        let cubeEntity = ModelEntity(mesh: .generateBox(size: [0.2, 0.2, 0.2]))
        cubeEntity.model?.materials = [material1]
        cubeEntity.position = [0, 0, 0]
        worldAnchor.addChild(cubeEntity)

        let material2 = SimpleMaterial(color: .red, isMetallic: false)
        let floorEntity = ModelEntity(mesh: .generateBox(size: [2, 0.1, 2]))
        floorEntity.model?.materials = [material2]
        floorEntity.position = [0, -1, 0]
        worldAnchor.addChild(floorEntity)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        arView.addGestureRecognizer(pan)
    }
    
    var icPosition = SIMD3<Float>(0, 0, 0)
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            let translate = recognizer.translation(in: recognizer.view)
            let deltaUp = Float(translate.y / 200)
            let deltaRight = Float(translate.x / 100)
            pitch += deltaUp
            yaw += deltaRight
            recognizer.setTranslation(.zero, in: recognizer.view)
            
            print(String(format: "dUp: %.3f, pitch: %.1f, dRight: %.3f, yaw: %.1f", deltaUp * 57.3, pitch * 57.3, deltaRight * 57.3, yaw * 57.3))
            
            // move the camera around origin
            camera.position = [-icPosition.z * sin(yaw),
                                icPosition.z * sin(pitch),
                                icPosition.z * cos(pitch) * cos(yaw)]
            
            // rotate the camera to point at origin
            camera.setOrientation(Transform(pitch: -pitch, yaw: -yaw, roll: .zero).rotation, relativeTo: worldAnchor.anchor)
            
            // want: rotate scene around camera
//            worldAnchor.setOrientation(Transform(pitch: angleX, yaw: angleY, roll: .zero).rotation, relativeTo: camera.anchor)  // same, but light source spinning around objects
//            camera.setOrientation(Transform(pitch: angleX, yaw: angleY, roll: .zero).rotation, relativeTo: camera.anchor)  // same as original
//            camera.setPosition(Transform(pitch: pitch, yaw: yaw, roll: .zero).translation, relativeTo: worldAnchor.anchor)  // shoots off screen
        default: break
        }
    }
    
//    // rotate camera around scene x-axis, while continuing to point at scene center
//    private func rotateCameraAroundBoardCenter(deltaAngle: CGFloat) {
//        cameraNode.transform = SCNMatrix4Rotate(cameraNode.transform, Float(deltaAngle), 1, 0, 0)
//        let cameraAngle = CGFloat(cameraNode.eulerAngles.x)
//        let cameraDistance = CGFloat(3 * Box.width)
//        cameraNode.position = SCNVector3(0, -cameraDistance * sin(cameraAngle), cameraDistance * cos(cameraAngle))
//    }
}
