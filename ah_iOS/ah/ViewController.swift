//
//  ViewController.swift
//  FaceTraking
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // ARSCNView
    @IBOutlet var sceneView: ARSCNView!
    
    // UIImageView - Depth Image
    @IBOutlet weak var depthImageView: UIImageView!
    
    // Face Tracking
    private var faceNode = SCNNode()
    private var virtualFaceNode = SCNNode()
    
    private let serialQueue = DispatchQueue(label: "com.test.FaceTracking.serialSceneKitQueue")
    
    var shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Face Tracking
        guard ARFaceTrackingConfiguration.isSupported else { return }
    
        // Face Tracking
        UIApplication.shared.isIdleTimerDisabled = true
        
        // ARSCNView - ARSession
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // virtualFaceNode - ARSCNFaceGeometry
        let device = sceneView.device!
        let maskGeometry = ARSCNFaceGeometry(device: device)!
        
        maskGeometry.firstMaterial?.diffuse.contents = UIColor.lightGray
        maskGeometry.firstMaterial?.lightingModel = .physicallyBased
        
        virtualFaceNode.geometry = maskGeometry
        
        resetTracking()
        
        self.addTapGesture()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return true
    }

    // ViewController
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        resetTracking()
    }

    // ViewController
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    // Face Tracking
    func resetTracking() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        //configuration.providesAudioData = true
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // Face Tracking
    private func setupFaceNodeContent() {
        // faceNode
        for child in faceNode.childNodes {
            child.removeFromParentNode()
        }
        
        // virtualFaceNode
        print(virtualFaceNode)
        faceNode.addChildNode(virtualFaceNode)
    }
    
    // MARK: - ARSCNViewDelegate
    /// ARNodeTracking
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode = node
        serialQueue.async {
            self.setupFaceNodeContent()
        }
    }
    
    /// ARNodeTracking ARSCNFaceGeometry
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        let geometry = virtualFaceNode.geometry as! ARSCNFaceGeometry
        shapes = faceAnchor.blendShapes
        geometry.update(from: faceAnchor.geometry)
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        print(audioSampleBuffer)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.resetTracking()
        }
    }
    
    /// Depth Image
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //　15 fps
        guard let depth = frame.capturedDepthData?.depthDataMap else { return }
        
        //　CIImage
        let ciImage = CIImage.init(cvImageBuffer: depth)
        depthImageView.image = UIImage.init(ciImage:
            ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!)
        )
    }
}



// MARK: - UIImagePickerController
let baseline_vals = ["ay": [0.298766956, 0.142167151, 0.085799411, 0.133791447, 0.038765031, 0.023759159],
              "ee": [0.168310106, 0.10076052, 0.035495957, 0.088527273, 0.063122351, 0.041300956],
              "oo": [0.177990764, 0.293824002, 0.161934374, 0.850610912, 0.005674623, 0.004009779]]

let correction_strings = [["Open your jaw more!", "Close your jaw more!"],
                          ["Move your mouth forward!", "Move your mouth backward!"],
                          ["Open your lips more!", "Close your lips more!"],
                          ["Pucker your mouth more!", "Pucker your mouth less!"],
                          ["Move the left side of your mouth back!", "Move the left side of your mouth forward!"],
                          ["Move the right side of your mouth back!", "Move the right side of your mouth forward!"]]

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func addTapGesture(){
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        let jawOpen = (shapes[ARFaceAnchor.BlendShapeLocation.jawOpen] as! Double)
        let mouthFunnel = (shapes[ARFaceAnchor.BlendShapeLocation.mouthFunnel] as! Double)
        let mouthClose = (shapes[ARFaceAnchor.BlendShapeLocation.mouthClose] as! Double)
        let mouthPucker = (shapes[ARFaceAnchor.BlendShapeLocation.mouthPucker] as! Double)
        let mouthDimpleLeft = (shapes[ARFaceAnchor.BlendShapeLocation.mouthDimpleLeft] as! Double)
        let mouthDimpleRight = (shapes[ARFaceAnchor.BlendShapeLocation.mouthDimpleRight] as! Double)
        
        let actual = [jawOpen, mouthFunnel, mouthClose, mouthPucker, mouthDimpleLeft, mouthDimpleRight]
        
        var phoneme = "oo"
        var maxErr = maxError(baseline: baseline_vals[phoneme]!, actual: actual)
        
        //print(maxErr)
        
        if maxErr.0 < 80 {
            print(correction_strings[maxErr.2][maxErr.1 > 0 ? 0 : 1])
        } else {
            print("Good!")
        }
    }
    
    func squareError(baseline: [Double], actual: [Double]) -> Double {
        var leastSq = 0.0
        
        for i in 0..<baseline.count {
            var err = baseline[i] - actual[i]
            leastSq += err*err
        }
        
        return leastSq
    }
    
    func maxError(baseline: [Double], actual: [Double]) -> (Double,Double,Int) {
        var minScore = 100.0
        var err = 0.0
        var maxInd = 0
        
        for i in 0..<baseline.count {
            let c_max = baseline[i] - actual[i]
            let max_possible = (baseline[i] < 0.5) ? 1 - baseline[i] : baseline[i]
            let score = 100*(1 - abs(c_max) / max_possible)
            
            if score < minScore {
                minScore = score
                err = c_max
                maxInd = i
            }
        }
        
        return (minScore,err,maxInd)
    }
}
