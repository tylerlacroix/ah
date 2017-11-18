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

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    func addTapGesture(){
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        var jawOpen = (shapes[ARFaceAnchor.BlendShapeLocation.jawOpen] as! Double)
        var mouthFunnel = (shapes[ARFaceAnchor.BlendShapeLocation.mouthFunnel] as! Double)
        var mouthClose = (shapes[ARFaceAnchor.BlendShapeLocation.mouthClose] as! Double)
        var mouthPucker = (shapes[ARFaceAnchor.BlendShapeLocation.mouthPucker] as! Double)
        
        confidence(jmmm: [jawOpen, mouthFunnel, mouthClose, mouthPucker], vowel: "a")
        var str = String(jawOpen) + " " + String(mouthFunnel) + " " + String(mouthClose) + " " + String(mouthPucker)
        print(str)
    }
    
    func confidence(jmmm: [Double], vowel: String){
        let v_dict = ["a": [0.323729, 0.0618158, 0.0480391, 0.0595103], "e": [0.323729, 0.0618158, 0.0480391, 0.0595103], "o": [0.323729, 0.0618158, 0.0480391, 0.0595103]]
        let v = (v_dict[vowel] as! [Double])
        for  i in v {
            print(i)
        }
        
    }
}
