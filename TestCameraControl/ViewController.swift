//
//  ViewController.swift
//  TestCameraControl
//
//  Created by Phil Stern on 3/20/26.
//
//  Test of my version of pan and pinch.
//

import UIKit
import RealityKit

struct Constant {
    static let cameraDistance: Float = 5  // can't be at 0, for pinch to work
}

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

        camera.position.z = Constant.cameraDistance
        worldAnchor.addChild(camera)

        let material1 = SimpleMaterial(color: .green, isMetallic: false)
        let greenCube = ModelEntity(mesh: .generateBox(size: [0.2, 0.2, 0.2]))
        greenCube.model?.materials = [material1]
        greenCube.position = [0, 0, 0]
        worldAnchor.addChild(greenCube)

        let material2 = SimpleMaterial(color: .red, isMetallic: false)
        let redFloor = ModelEntity(mesh: .generateBox(size: [2, 0.1, 2]))
        redFloor.model?.materials = [material2]
        redFloor.position = [0, -1, 0]
        worldAnchor.addChild(redFloor)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        arView.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        arView.addGestureRecognizer(pinch)
    }
        
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        let translate = recognizer.translation(in: recognizer.view)
        let deltaUp = Float(translate.y / 200)
        let deltaRight = Float(translate.x / 100)
        recognizer.setTranslation(.zero, in: recognizer.view)
        
        pitch += deltaUp
        yaw += deltaRight
        
        // move camera around world center
        camera.position = [-Constant.cameraDistance * sin(yaw),
                            Constant.cameraDistance * sin(pitch),
                            Constant.cameraDistance * cos(pitch) * cos(yaw)]
        
        // point camera at world center
        camera.look(at: .zero, from: camera.position, relativeTo: nil)
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
}
