//
//  ViewController.swift
//  BicoptAR
//
//  Created by Kevin M. Thomas on 1/11/19.
//  Copyright © 2019 Kevin Thomas. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    /////////////////////
    // MARK: - VARIABLES
    ////////////////////
    
    // Used to instantiate sceneView
    @IBOutlet var sceneView: ARSCNView!
    
    // Used to display target to player
    @IBOutlet weak var target: UIImageView!
    
    // Used to display timer to player
    @IBOutlet weak var timerLabel: UILabel!
    
    // Used to display score to player
    @IBOutlet weak var scoreLabel: UILabel!
    
    // Used to store the score
    var score = 0
    
    ///////////////////
    // MARK: - BUTTONS
    //////////////////
    
    // Bullet button
    @IBOutlet weak var onBulletButton: UIButton!
    @IBAction func onBulletButton(_ sender: Any) {
        fireMissile(type: "bullet")
    }
    
    ////////////////////////
    // MARK: - CREATE NODES
    ///////////////////////
    
    // Create trackerNode and gameNode and position vector
    var center: CGPoint!
    let trackerNode = SCNScene(named: "art.scnassets/tracker.scn")!.rootNode
    var gameNode = SCNScene(named: "art.scnassets/scene.scn")!.rootNode
    var positions = [SCNVector3]()
    
    //////////////////////
    // MARK: - GAME STATE
    /////////////////////
    
    // Create game state
    var isGameOn = false
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if !isGameOn {
            let hitTest = sceneView.hitTest(center, types: .featurePoint)
            let result = hitTest.last
            guard let transform = result?.worldTransform else { return }
            let thirdColumn = transform.columns.3
            let position = SCNVector3Make(thirdColumn.x, thirdColumn.y, thirdColumn.z)
            positions.append(position)
            let lastTenPositions = positions.suffix(10)
            trackerNode.position = getAveragePosition(from: lastTenPositions)
        }
    }
    
    // Get position for arrow placement
    func getAveragePosition(from positions: ArraySlice<SCNVector3>) -> SCNVector3 {
        var averageX : Float = 0
        var averageY : Float = 0
        var averageZ : Float = 0
        
        for position in positions {
            averageX += position.x
            averageY += position.y
            averageZ += position.z
        }
        
        let count = Float(positions.count)
        return SCNVector3Make(averageX / count, averageY / count, averageZ / count)
    }
    
    // Create game loop
    func initGame() {
        // Show buttons and labels on init
        target.isHidden = false
        timerLabel.isHidden = false
        onBulletButton.isHidden = false
        scoreLabel.isHidden = false
        
        // Add bicopters
        addBicopters()
        
        // Play background music
        playBackgroundMusic()
        
        // Start timer
        runTimer()
        
        // Set game on
        isGameOn = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOn {
            return
        } else {
            // Place the gameNode
            guard let angle = sceneView.session.currentFrame?.camera.eulerAngles.y else { return }
            gameNode.position = trackerNode.position
            gameNode.eulerAngles.y = angle
            trackerNode.removeFromParentNode()
            sceneView.scene.rootNode.addChildNode(gameNode)
            initGame()
        }
    }
    
    /////////////////
    // MARK: - MATHS
    ////////////////
    
    // (direction, position)
    func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            // 4x4 transform matrix describing camera in world space
            let mat = SCNMatrix4(frame.camera.transform)
            // Orientation of camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            // Location of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)
            
            return (dir, pos)
        }
        
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    //////////////////////////
    // MARK: - VIEW FUNCTIONS
    /////////////////////////
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // Create default lighting
        self.sceneView.autoenablesDefaultLighting = true
        
        // Set the physics delegate
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Update the labels cornerRadius at runtime
        timerLabel.layer.masksToBounds = true
        timerLabel.layer.cornerRadius = 30
        scoreLabel.layer.masksToBounds = true
        scoreLabel.layer.cornerRadius = 30
        
        // Obtain center of camera view and add arrow node
        center = view.center
        sceneView.scene.rootNode.addChildNode(trackerNode)
        
        // Hide buttons and labels on init
        target.isHidden = true
        timerLabel.isHidden = true
        onBulletButton.isHidden = true
        scoreLabel.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Create environmental lighting
        configuration.environmentTexturing = .automatic
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    //////////////////
    // MARK: - TIMERS
    /////////////////
    
    // Add bicopters timers to stop new unicopters being init after game session
    var bicopterTimer1 = Timer()
    var bicopterTimer2 = Timer()
    
    // Add bicopter method init a timer
    func addBicopters() {
        bicopterTimer1 = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.addBicopter1TargetNodes)), userInfo: nil, repeats: true)
        bicopterTimer2 = Timer.scheduledTimer(timeInterval: 3, target: self, selector: (#selector(self.addBicopter2TargetNodes)), userInfo: nil, repeats: true)
    }
    
    // To store how many sceonds the game is played for
    var seconds = 30
    
    // Timer
    var timer = Timer()
    
    // To keep track of whether the timer is on
    var isTimerRunning = false
    
    // To run the timer
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
    }
    
    // Decrements seconds by 1, updates the timerLabel and calls gameOver if seconds is 0
    @objc func updateTimer() {
        if seconds == 0 {
            timer.invalidate()
            gameOver()
        } else {
            seconds -= 1
            timerLabel.text = "\(seconds)"
        }
    }
    
    // Resets the timer
    func resetTimer() {
        timer.invalidate()
        seconds = 30
        timerLabel.text = "\(seconds)"
    }
    
    /////////////////////
    // MARK: - GAME OVER
    ////////////////////
    
    func gameOver() {
        // Store the score in UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(score, forKey: "score")
        
        // Go back to the Home View Controller
        self.dismiss(animated: true, completion: nil)
        
        // Invalidate bicopter timers
        bicopterTimer1.invalidate()
        bicopterTimer2.invalidate()
    }
    
    //////////////////////////////
    // MARK: - MISSILES & TARGETS
    /////////////////////////////
    
    // Creates bicopter1 or bicopter2 node and 'fires' it
    func fireMissile(type : String){
        var node = SCNNode()
        
        // Create node
        node = createMissile(type: type)
        
        // Get the users position and direction
        let (direction, position) = self.getUserVector()
        node.position = position
        
        var nodeDirection = SCNVector3()
        
        switch type {
        case "bullet":
            nodeDirection  = SCNVector3(direction.x * 4, direction.y * 4, direction.z * 4)
            node.physicsBody?.applyForce(nodeDirection, at: SCNVector3(0.1, 0, 0), asImpulse: true)
            playSound(sound: "mossbergShotgun", format: "wav")
            
            // Remove ball after 3 seconds
            let disapear = SCNAction.fadeOut(duration: 0.3)
            node.runAction(.sequence([.wait(duration: 6), disapear]))
        default:
            nodeDirection = direction
        }
        
        // Move node
        node.physicsBody?.applyForce(nodeDirection, asImpulse: true)
        
        // Add node to scene
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    // Create nodes
    func createMissile(type: String) -> SCNNode {
        var node = SCNNode()
        
        // Using case statement to allow variations of scale and rotations
        switch type {
        case "bullet":
            let scene = SCNScene(named: "art.scnassets/bullet.scn")
            node = (scene?.rootNode.childNode(withName: "bullet", recursively: true)!)!
            node.scale = SCNVector3(0.2, 0.2, 0.2)
            node.name = "bullet"
        default:
            node = SCNNode()
        }
        
        // The physics body governs how the object interacts with other objects and its environment
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        // These bitmasks used to define "collisions" with other objects
        node.physicsBody?.categoryBitMask = CollisionCategory.missileCategory.rawValue
        node.physicsBody?.collisionBitMask = CollisionCategory.targetCategory.rawValue
        return node
    }
    
    // Add bicopter1 target nodes
    @objc func addBicopter1TargetNodes() {
        var node = SCNNode()
        
        let scene = SCNScene(named: "art.scnassets/bicopter1.scn")
        node = (scene?.rootNode.childNode(withName: "bicopter1", recursively: true)!)!
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.name = "bicopter1"
        
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        // Place randomly, within thresholds
        node.position = SCNVector3(randomFloat(min: -3, max: 3), randomFloat(min: -2, max: 2), -8)
        
        // Create smoke particle system
        let particleSystem = SCNParticleSystem(named: "smoke.scnp", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        
        // Add particle to the unicopter
        node.addChildNode(particleNode)
        particleNode.position = SCNVector3Make(0, 0.25, -5)
        
        // For the collision detection
        node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
        node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
        
        // Remove bicopter after 2 seconds
        let disapear = SCNAction.fadeOut(duration: 0.3)
        node.runAction(.sequence([.wait(duration: 2), disapear]))
        
        // Add to scene
        sceneView.scene.rootNode.addChildNode(node)
        
        // Accelerate
        let force = simd_make_float4(0, 0, randomFloat(min: 10, max: 40), 0)
        let rotatedForce = simd_mul(node.presentation.simdTransform, force)
        let vectorForce = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
        node.physicsBody?.applyForce(vectorForce, asImpulse: true)
    }
    
    @objc func addBicopter2TargetNodes() {
        var node = SCNNode()
        
        let scene = SCNScene(named: "art.scnassets/bicopter2.scn")
        node = (scene?.rootNode.childNode(withName: "bicopter2", recursively: true)!)!
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.name = "bicopter2"
        
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        // Place randomly, within thresholds
        node.position = SCNVector3(randomFloat(min: -3, max: 3), randomFloat(min: -2, max: 2), -8)
        
        // Create smoke particle system
        let particleSystem = SCNParticleSystem(named: "smoke.scnp", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        
        // Add particle to the unicopter
        node.addChildNode(particleNode)
        particleNode.position = SCNVector3Make(0, 0.25, -5)
        
        // For the collision detection
        node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
        node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
        
        // Remove bicopter after 1 seconds
        let disapear = SCNAction.fadeOut(duration: 0.3)
        node.runAction(.sequence([.wait(duration: 1), disapear]))
        
        // Add to scene
        sceneView.scene.rootNode.addChildNode(node)
        
        // Accelerate
        let force = simd_make_float4(0, 0, randomFloat(min: 40, max: 60), 0)
        let rotatedForce = simd_mul(node.presentation.simdTransform, force)
        let vectorForce = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
        node.physicsBody?.applyForce(vectorForce, asImpulse: true)
    }
    
    // Create random float between specified ranges
    func randomFloat(min: Float, max: Float) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Release any cached data, images, etc that aren't in use
    }
    
    /////////////////////////////
    // MARK: - ARSCNVIEWDELEGATE
    ////////////////////////////
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
    */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    ////////////////////////////
    // MARK: - CONTACT DELEGATE
    ///////////////////////////
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("** Collision!! " + contact.nodeA.name! + " hit " + contact.nodeB.name!)
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue {
            if(contact.nodeA.name! == "copter2" || contact.nodeB.name! == "copter2") {
                score += 5
            } else {
                score += 1
            }
            
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
                contact.nodeB.removeFromParentNode()
                self.scoreLabel.text = String(self.score)
            }
            
            playSound(sound: "explosion", format: "mp3")
            let explosion = SCNParticleSystem(named: "fire", inDirectory: nil)
            contact.nodeB.addParticleSystem(explosion!)
        }
    }
    
    //////////////////
    // MARK: - SOUNDS
    /////////////////
    
    var player: AVAudioPlayer?
    
    // Audio player method for bullet and explosion
    func playSound(sound : String, format: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: format) else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // Background music method
    func playBackgroundMusic(){
        let audioNode = SCNNode()
        let audioSource = SCNAudioSource(fileNamed: "sarth.aiff")!
        let audioPlayer = SCNAudioPlayer(source: audioSource)
        
        audioNode.addAudioPlayer(audioPlayer)
        
        let play = SCNAction.playAudio(audioSource, waitForCompletion: true)
        audioNode.runAction(play)
        sceneView.scene.rootNode.addChildNode(audioNode)
    }
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    
    static let missileCategory  = CollisionCategory(rawValue: 1 << 0)
    static let targetCategory = CollisionCategory(rawValue: 1 << 1)
    static let otherCategory = CollisionCategory(rawValue: 1 << 2)
}

// Helper function inserted by Swift 4.2 migrator
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
