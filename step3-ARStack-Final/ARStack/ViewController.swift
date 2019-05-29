//
//  ViewController.swift
//  ARStack
//
//  Created by CoderXu on 2017/10/14.
//  Copyright © 2017年 XanderXu. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


let boxheight:CGFloat = 0.05
let boxLengthWidth:CGFloat = 0.4
let actionOffet:Float = 0.6
let actionSpeed:Float = 0.011

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var sessionInfoLabel: UILabel!
    
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var restartButton: UIButton!
    
    @IBOutlet weak var scoreLabel: UILabel!
    

    weak var baseNode: SCNNode?

    weak var planeNode: SCNNode?

    var updateCount: NSInteger = 0
    
    var gameNode:SCNNode?
    
    var direction = true
    var height = 0
    
    
    var previousSize = SCNVector3(boxLengthWidth, boxheight, boxLengthWidth)
    var previousPosition = SCNVector3(0, boxheight*0.5, 0)
    var currentSize = SCNVector3(boxLengthWidth, boxheight, boxLengthWidth)
    var currentPosition = SCNVector3Zero
    
    var offset = SCNVector3Zero
    var absoluteOffset = SCNVector3Zero
    var newSize = SCNVector3Zero
    
    
    var perfectMatches = 0
    var sounds = [String: SCNAudioSource]()


    override func viewDidLoad() {
        super.viewDidLoad()
        playButton.isHidden = true
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        // Create a new scene
        let scene = SCNScene()
        // Set the scene to the view
        sceneView.scene = scene
        
        loadSound(name: "GameOver", path: "art.scnassets/Audio/GameOver.wav")
        loadSound(name: "PerfectFit", path: "art.scnassets/Audio/PerfectFit.wav")
        loadSound(name: "SliceBlock", path: "art.scnassets/Audio/SliceBlock.wav")
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil) { (noti) in
            self.resetAll()
        }
    }
    
    //    When the application has loaded and the camera loads
    override func viewWillAppear(_ animated: Bool) {
        print("VIEEEEEEEEEW HAS APPEARED")
        super.viewWillAppear(animated)
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        resetAll()
        print("viewWillAppear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    @IBAction func playButtonClick(_ sender: UIButton) {

        playButton.isHidden = true
        sessionInfoLabel.isHidden = true
        
        stopTracking()
        
        sceneView.debugOptions = []
        
        planeNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        planeNode?.opacity = 1
        baseNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        
        
        gameNode?.removeFromParentNode();
        gameNode = SCNNode()
        let gameChildNodes = SCNScene(named: "art.scnassets/Scenes/GameScene.scn")!.rootNode.childNodes
        for node in gameChildNodes {
            gameNode?.addChildNode(node)
        }
        baseNode?.addChildNode(gameNode!)
        resetGameData()
        
        
        let boxNode = SCNNode(geometry: SCNBox(width: boxLengthWidth, height: boxheight, length: boxLengthWidth, chamferRadius: 0))
        boxNode.position.z = -actionOffet
        boxNode.position.y = Float(boxheight * 0.5)
        boxNode.name = "Block\(height)"
        boxNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.1 * CGFloat(height % 10), green: 0.03*CGFloat(height%30), blue: 1-0.1 * CGFloat(height % 10), alpha: 1)
        boxNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: boxNode.geometry!, options: nil))
        gameNode?.addChildNode(boxNode)
    }
    @IBAction func restartButtonClick(_ sender: UIButton) {
        resetAll()
    }
    @IBAction func handleTap(_ sender: Any) {
        if let currentBoxNode = gameNode?.childNode(withName: "Block\(height)", recursively: false) {
            currentPosition = currentBoxNode.presentation.position
            let boundsMin = currentBoxNode.boundingBox.min
            let boundsMax = currentBoxNode.boundingBox.max
            currentSize = boundsMax - boundsMin
            
            offset = previousPosition - currentPosition
            absoluteOffset = offset.absoluteValue()
            newSize = currentSize - absoluteOffset
            
            if height % 2 == 0 && newSize.z <= 0 {
                gameOver()
                playSound(sound: "GameOver", node: currentBoxNode)
                height += 1
                currentBoxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: currentBoxNode.geometry!, options: nil))
                return
            } else if height % 2 != 0 && newSize.x <= 0 {
                gameOver()
                playSound(sound: "GameOver", node: currentBoxNode)
                height += 1
                currentBoxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: currentBoxNode.geometry!, options: nil))
                return
            }
            
            checkPerfectMatch(currentBoxNode)
            
            currentBoxNode.geometry = SCNBox(width: CGFloat(newSize.x), height: boxheight, length: CGFloat(newSize.z), chamferRadius: 0)
            currentBoxNode.position = SCNVector3Make(currentPosition.x + (offset.x/2), currentPosition.y, currentPosition.z + (offset.z/2))
            currentBoxNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: currentBoxNode.geometry!, options: nil))
            currentBoxNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.1 * CGFloat(height % 10), green: 0.03*CGFloat(height%30), blue: 1-0.1 * CGFloat(height % 10), alpha: 1)
            addBrokenBlock(currentBoxNode)
            addNewBlock(currentBoxNode)
            playSound(sound: "SliceBlock", node: currentBoxNode)
            
            if height >= 5 {
                gameNode?.enumerateChildNodes({ (node, stop) in
                    if node.light != nil {//灯光节点不隐藏
                        return
                    }
                    if node.position.y < Float(self.height-5) * Float(boxheight) {
                        node.isHidden = true
                    }
                })
                
                let moveUpAction = SCNAction.move(by: SCNVector3Make(0.0, Float(-boxheight), 0.0), duration: 0.2)
                
                gameNode?.runAction(moveUpAction)
            }
            
            scoreLabel.text = "\(height+1)"
            
            previousSize = SCNVector3Make(newSize.x, Float(boxheight), newSize.z)
            previousPosition = currentBoxNode.position
            height += 1
        }
    }
    
}

extension ViewController {
    func addNewBlock(_ currentBoxNode: SCNNode) {
        let newBoxNode = SCNNode(geometry: SCNBox(width: CGFloat(newSize.x), height: boxheight, length: CGFloat(newSize.z), chamferRadius: 0))
        newBoxNode.position = SCNVector3Make(currentBoxNode.position.x, currentPosition.y + Float(boxheight), currentBoxNode.position.z)
        newBoxNode.name = "Block\(height+1)"
        newBoxNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.1 * CGFloat((height+1) % 10), green: 0.03*CGFloat((height+1)%30), blue: 1-0.1 * CGFloat((height+1) % 10), alpha: 1)
        newBoxNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: newBoxNode.geometry!, options: nil))
        if height % 2 == 0 {
            newBoxNode.position.x = -actionOffet
        } else {
            newBoxNode.position.z = -actionOffet
        }
        
        gameNode?.addChildNode(newBoxNode)
    }
    
    func addBrokenBlock(_ currentBoxNode: SCNNode) {
        let brokenBoxNode = SCNNode()
        brokenBoxNode.name = "Broken \(height)"
        
        if height % 2 == 0 && absoluteOffset.z > 0 {
            // 1
            brokenBoxNode.geometry = SCNBox(width: CGFloat(currentSize.x), height: boxheight, length: CGFloat(absoluteOffset.z), chamferRadius: 0)
            
            // 2
            if offset.z > 0 {
                brokenBoxNode.position.z = currentBoxNode.position.z - (offset.z/2) - ((currentSize - offset).z/2)
            } else {
                brokenBoxNode.position.z = currentBoxNode.position.z - (offset.z/2) + ((currentSize + offset).z/2)
            }
            brokenBoxNode.position.x = currentBoxNode.position.x
            brokenBoxNode.position.y = currentPosition.y
            
            // 3
            brokenBoxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: brokenBoxNode.geometry!, options: nil))
            brokenBoxNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.1 * CGFloat(height % 10), green: 0.03*CGFloat(height%30), blue: 1-0.1 * CGFloat(height % 10), alpha: 1)
            gameNode?.addChildNode(brokenBoxNode)
            
            // 4
        } else if height % 2 != 0 && absoluteOffset.x > 0 {
            brokenBoxNode.geometry = SCNBox(width: CGFloat(absoluteOffset.x), height: boxheight, length: CGFloat(currentSize.z), chamferRadius: 0)
            
            if offset.x > 0 {
                brokenBoxNode.position.x = currentBoxNode.position.x - (offset.x/2) - ((currentSize - offset).x/2)
            } else {
                brokenBoxNode.position.x = currentBoxNode.position.x - (offset.x/2) + ((currentSize + offset).x/2)
            }
            brokenBoxNode.position.y = currentPosition.y
            brokenBoxNode.position.z = currentBoxNode.position.z
            
            brokenBoxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: brokenBoxNode.geometry!, options: nil))
            brokenBoxNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.1 * CGFloat(height % 10), green: 0.03*CGFloat(height%30), blue: 1-0.1 * CGFloat(height % 10), alpha: 1)
            gameNode?.addChildNode(brokenBoxNode)
        }
    }
    
    func checkPerfectMatch(_ currentBoxNode: SCNNode) {
        if height % 2 == 0 && absoluteOffset.z <= 0.005 {
            playSound(sound: "PerfectFit", node: currentBoxNode)
            currentBoxNode.position.z = previousPosition.z
            currentPosition.z = previousPosition.z
            perfectMatches += 1
            if perfectMatches >= 7 && currentSize.z < 1 {
                newSize.z += 0.005
            }
            
            offset = previousPosition - currentPosition
            absoluteOffset = offset.absoluteValue()
            newSize = currentSize - absoluteOffset
        } else if height % 2 != 0 && absoluteOffset.x <= 0.005 {
            playSound(sound: "PerfectFit", node: currentBoxNode)
            currentBoxNode.position.x = previousPosition.x
            currentPosition.x = previousPosition.x
            perfectMatches += 1
            if perfectMatches >= 7 && currentSize.x < 1 {
                newSize.x += 0.005
            }
            
            offset = previousPosition - currentPosition
            absoluteOffset = offset.absoluteValue()
            newSize = currentSize - absoluteOffset
        } else {
            perfectMatches = 0
        }
    }

    func loadSound(name: String, path: String) {
        if let sound = SCNAudioSource(fileNamed: path) {
            sound.isPositional = false
            sound.volume = 1
            sound.load()
            sounds[name] = sound
        }
    }
    
    func playSound(sound: String, node: SCNNode) {
        node.runAction(SCNAction.playAudio(sounds[sound]!, waitForCompletion: false))
    }
    
    
    func gameOver() {
        
        let fullAction = SCNAction.customAction(duration: 0.3) { _,_ in
            let moveAction = SCNAction.move(to: SCNVector3Make(0, 0, 0), duration: 0.3)
            self.gameNode?.runAction(moveAction)
        }
        
        gameNode?.runAction(fullAction)
        playButton.isHidden = false
        gameNode?.enumerateChildNodes({ (node, stop) in
            
            node.isHidden = false
            
        })
    }
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
      
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    private func stopTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .init(rawValue: 0)
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration)
    }
    
    private func resetAll() {
        playButton.isHidden = true
        sessionInfoLabel.isHidden = false
        resetTracking()
        updateCount = 0
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        resetGameData()
        print("resetAll")
    }
    private func resetGameData() {
        height = 0
        scoreLabel.text = "\(height)"
        
        direction = true
        perfectMatches = 0
        previousSize = SCNVector3(boxLengthWidth, boxheight, boxLengthWidth)
        previousPosition = SCNVector3(0, boxheight*0.5, 0)
        currentSize = SCNVector3(boxLengthWidth, boxheight, boxLengthWidth)
        currentPosition = SCNVector3Zero
        
        offset = SCNVector3Zero
        absoluteOffset = SCNVector3Zero
        newSize = SCNVector3Zero
    }
}

extension ViewController:ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    
        if let planeAnchor = anchor as? ARPlaneAnchor,node.childNodes.count < 1,updateCount < 1 {
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            plane.firstMaterial?.diffuse.contents = UIColor.red
            planeNode = SCNNode(geometry: plane)
            planeNode?.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode?.eulerAngles.x = -.pi / 2
            
            
            planeNode?.opacity = 0.25
            
            node.addChildNode(planeNode!)
            
            
            let base = SCNBox(width: 0.5, height: 0, length: 0.5, chamferRadius: 0);
            base.firstMaterial?.diffuse.contents = UIColor.gray;
            baseNode = SCNNode(geometry:base);
            baseNode?.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
            
            node.addChildNode(baseNode!)
        }
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        updateCount += 1
        if updateCount > 20 {
            DispatchQueue.main.async {
                self.playButton.isHidden = false
            }
        }
        
        
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
     
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
        sessionInfoLabel.text = "Session失败: \(error.localizedDescription)"
        resetTracking()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        
        sessionInfoLabel.text = "Session被打断"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        
        sessionInfoLabel.text = "Session打断结束"
        resetTracking()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    // MARK:- SCNSceneRendererDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let gameNode2 = gameNode else {
            return
        }
        for node in gameNode2.childNodes {
            if node.presentation.position.y <= -10 {
                node.removeFromParentNode()
            }
        }
        
        // 1
        if let currentNode = gameNode?.childNode(withName: "Block\(height)", recursively: false) {
            // 2
            if height % 2 == 0 {
                // 3
                if currentNode.position.z >= actionOffet {
                    direction = false
                } else if currentNode.position.z <= -actionOffet {
                    direction = true
                }
                
                // 4
                switch direction {
                case true:
                    currentNode.position.z += actionSpeed
                case false:
                    currentNode.position.z -= actionSpeed
                }
                // 5
            } else {
                if currentNode.position.x >= actionOffet {
                    direction = false
                } else if currentNode.position.x <= -actionOffet {
                    direction = true
                }
                
                switch direction {
                case true:
                    currentNode.position.x += actionSpeed
                case false:
                    currentNode.position.x -= actionSpeed
                }
            }
        }
    }
}
