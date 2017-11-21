//
//  FaceScoreViewController.swift
//  FaceTraking
//
//  Created by Tyler Lacroix on 11/18/17.

import UIKit
import ARKit

class FaceScoreViewController: ModalViewController, OEEventsObserverDelegate, ARSCNViewDelegate, ARSessionDelegate {
    public var phoneme = "oo"
    
    var slt = Slt()
    var openEarsEventsObserver = OEEventsObserver()
    var fliteController = OEFliteController()
    
    var usingStartingLanguageModel = Bool()
    var startupFailedDueToLackOfPermissions = Bool()
    var restartAttemptsDueToPermissionRequests = Int()
    var pathToFirstDynamicallyGeneratedLanguageModel: String!
    var pathToFirstDynamicallyGeneratedDictionary: String!
    var pathToSecondDynamicallyGeneratedLanguageModel: String!
    var pathToSecondDynamicallyGeneratedDictionary: String!
    
    @IBOutlet var resetButton:UIButton!
    @IBOutlet var mouthShapeCircleView:CircleView!
    @IBOutlet var pronounciationCircleView:CircleView!
    @IBOutlet var mouthShapePercent:UILabel!
    @IBOutlet var pronounciationPercent:UILabel!
    @IBOutlet var tipLabel:UILabel!
    
    // ARSCNView
    @IBOutlet var sceneView: ARSCNView!
    
    // Face Tracking
    private var faceNode = SCNNode()
    private var virtualFaceNode = SCNNode()
    
    private let serialQueue = DispatchQueue(label: "com.test.FaceTracking.serialSceneKitQueue")
    
    var shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* AUDIO */
        self.openEarsEventsObserver.delegate = self
        self.restartAttemptsDueToPermissionRequests = 0
        self.startupFailedDueToLackOfPermissions = false
        
        let languageModelGenerator = OELanguageModelGenerator()
        
        // This is the language model (vocabulary) we're going to start up with. You can replace these words with the words you want to use.
        
        let firstLanguageArray = [phoneme]
        let firstVocabularyName = "FirstVocabulary"
        let firstLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: firstLanguageArray, withFilesNamed: firstVocabularyName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"))
        
        if(firstLanguageModelGenerationError != nil) {
            print("Error while creating initial language model: \(firstLanguageModelGenerationError)")
        } else {
            self.pathToFirstDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: firstVocabularyName) // these are convenience methods you can use to reference the file location of a language model that is known to have been created successfully.
            self.pathToFirstDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: firstVocabularyName) // these are convenience methods you can use to reference the file location of a dictionary that is known to have been created successfully.
            self.usingStartingLanguageModel = true // Just keeping track of which model we're using.
            
            do {
                try OEPocketsphinxController.sharedInstance().setActive(true) // Setting the shared OEPocketsphinxController active is necessary before any of its properties are accessed.
                OEPocketsphinxController.sharedInstance().vadThreshold = 3.5
                OEPocketsphinxController.sharedInstance().secondsOfSilenceToDetect = 0.5
            }
            catch {
                print("Error: it wasn't possible to set the shared instance to active: \"\(error)\"")
            }
            
            // OEPocketsphinxController.sharedInstance().verbosePocketSphinx = true // If you encounter any issues, set this to true to get verbose logging output from OEPocketsphinxController to either diagnose your issue or provide information when asking for help at the forums.
            
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            }
        }
        
        
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
        
        //self.addTapGesture()
    }
    
    var detectedAudio = false
    var mouthShapeScore = (0.0,0.0,0)
    var pronounciationScore = 0.0
    
    @IBAction func startTest() {
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
        
        var timerCount = 25
        detectedAudio = false
        mouthShapeScore = (0.0,0.0,0)
        pronounciationScore = 0.0
        
        //resetButton.titleLabel!.text = "Processing..."
        resetButton.setTitle("Processing...", for: UIControlState.normal)
        resetButton.isEnabled = false
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer) in
            timerCount -= 1
            let score = self.calcScore()
            
            if score.0 > self.mouthShapeScore.0 {
                self.mouthShapeScore = score
            }
            
            if timerCount == 0 {
                timer.invalidate()
                self.endTest()
            }
        }
    }
    
    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) {
        print(recognitionScore)
        let score = 1/(1+pow(M_E, (-0.00007*Double(recognitionScore)!-4.516)))
        detectedAudio = true
        
        if (score > pronounciationScore) {
            pronounciationScore = score
        }
        
        print("Local callback: The received hypothesis is \(hypothesis!) with a score of \(score) and an ID of \(utteranceID!)")
        
        // This is how to use an available instance of OEFliteController. We're going to repeat back the command that we heard with the voice we've chosen.
        // self.fliteController.say(_:"You said \(hypothesis!)", with:self.slt)
    }
    
    let correction_strings = [["Open your jaw more!", "Close your jaw more!"],
                              ["Move your mouth forward!", "Move your mouth backward!"],
                              ["Open your lips more!", "Close your lips more!"],
                              ["Pucker your mouth more!", "Pucker your mouth less!"],
                              ["Move the left side of your mouth back!", "Move the left side of your mouth forward!"],
                              ["Move the right side of your mouth back!", "Move the right side of your mouth forward!"],
                              ["Stretch your mouth more!", "Stretch your mouth less!"],
                              ["Stretch your mouth more!", "Stretch your mouth less!"]]
    
    func endTest() {
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(stopListeningError)")
            }
        }
        
        resetButton.setTitle("Go!", for: UIControlState.normal)
        resetButton.isEnabled = true
        
        mouthShapeCircleView.animateCircle(percent:CGFloat(mouthShapeScore.0), duration: 0.5)
        mouthShapePercent.text = String(Int(100*mouthShapeScore.0)) + "%"
        
        if mouthShapeScore.0 < 0.8 {
            tipLabel.text = correction_strings[mouthShapeScore.2][mouthShapeScore.1 > 0 ? 0 : 1]
        } else {
            tipLabel.text = "Good!"
        }
        
        if detectedAudio == false {
            tipLabel.text = "No audio detected!"
            pronounciationScore = 0.005
        }
        
        pronounciationCircleView.animateCircle(percent:CGFloat(pronounciationScore), duration: 0.5)
        pronounciationPercent.text = String(Int(100*pronounciationScore)) + "%"
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
    
    // An optional delegate method of OEEventsObserver which informs that the interruption to the audio session ended.
    func audioSessionInterruptionDidEnd() {
        print("Local callback:  AudioSession interruption ended.") // Log it.
        // We're restarting the previously-stopped listening loop.
        if(!OEPocketsphinxController.sharedInstance().isListening){
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the audio input became unavailable.
    func audioInputDidBecomeUnavailable() {
        print("Local callback:  The audio input has become unavailable") // Log it.
        
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeUnavailable: \(stopListeningError)")
            }
        }
        
        // An optional delegate method of OEEventsObserver which informs that the unavailable audio input became available again.
        func audioInputDidBecomeAvailable() {
            print("Local callback: The audio input is available") // Log it.
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        }
        // An optional delegate method of OEEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
        func audioRouteDidChange(toRoute newRoute: String!) {
            print("Local callback: Audio route change. The new audio route is \(newRoute)") // Log it.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeAvailable: \(stopListeningError)")
            }
        }
        
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the Pocketsphinx recognition loop has entered its actual loop.
    // This might be useful in debugging a conflict between another sound class and Pocketsphinx.
    func pocketsphinxRecognitionLoopDidStart() {
        
        print("Local callback: Pocketsphinx started.") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is now listening for speech.
    func pocketsphinxDidStartListening() {
        
        print("Local callback: Pocketsphinx is now listening.") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
    func pocketsphinxDidDetectSpeech() {
        print("Local callback: Pocketsphinx has detected speech.") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance.
    // This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between
    // this method being called and the hypothesis being returned.
    func pocketsphinxDidDetectFinishedSpeech() {
        print("Local callback: Pocketsphinx has detected a second of silence, concluding an utterance.") // Log it.
    }
    
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx has exited its recognition loop, most
    // likely in response to the OEPocketsphinxController being told to stop listening via the stopListening method.
    func pocketsphinxDidStopListening() {
        print("Local callback: Pocketsphinx has stopped listening.") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
    // Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
    // in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to suspend recognition via the suspendRecognition method.
    func pocketsphinxDidSuspendRecognition() {
        print("Local callback: Pocketsphinx has suspended recognition.") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
    // having been suspended it is now resuming.  This can happen as a result of Flite speech completing
    // on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to resume recognition via the resumeRecognition method.
    func pocketsphinxDidResumeRecognition() {
        print("Local callback: Pocketsphinx has resumed recognition.") // Log it.
    }
    
    // An optional delegate method which informs that Pocketsphinx switched over to a new language model at the given URL in the course of
    // recognition. This does not imply that it is a valid file or that recognition will be successful using the file.
    func pocketsphinxDidChangeLanguageModel(toFile newLanguageModelPathAsString: String!, andDictionary newDictionaryPathAsString: String!) {
        
        print("Local callback: Pocketsphinx is now using the following language model: \n\(newLanguageModelPathAsString!) and the following dictionary: \(newDictionaryPathAsString!)")
    }
    
    // An optional delegate method of OEEventsObserver which informs that Flite is speaking, most likely to be useful if debugging a
    // complex interaction between sound classes. You don't have to do anything yourself in order to prevent Pocketsphinx from listening to Flite talk and trying to recognize the speech.
    func fliteDidStartSpeaking() {
        print("Local callback: Flite has started speaking") // Log it.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Flite is finished speaking, most likely to be useful if debugging a
    // complex interaction between sound classes.
    func fliteDidFinishSpeaking() {
        print("Local callback: Flite has finished speaking") // Log it.
    }
    
    func pocketSphinxContinuousSetupDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Setting up the continuous recognition loop has failed for the reason \(reasonForFailure), please turn on OELogging.startOpenEarsLogging() to learn more.") // Log it.
    }
    
    func pocketSphinxContinuousTeardownDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Tearing down the continuous recognition loop has failed for the reason %, please turn on [OELogging startOpenEarsLogging] to learn more.", reasonForFailure) // Log it.
    }
    
    func testRecognitionCompleted() { // A test file which was submitted for direct recognition via the audio driver is done.
        print("Local callback: A test file which was submitted for direct recognition via the audio driver is done.") // Log it.
        if(OEPocketsphinxController.sharedInstance().isListening) { // If we're listening, stop listening.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in testRecognitionCompleted: \(stopListeningError)")
            }
        }
        
    }
    /** Pocketsphinx couldn't start because it has no mic permissions (will only be returned on iOS7 or later).*/
    func pocketsphinxFailedNoMicPermissions() {
        print("Local callback: The user has never set mic permissions or denied permission to this app's mic, so listening will not start.")
        self.startupFailedDueToLackOfPermissions = true
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(stopListeningError). Will try again in 10 seconds.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        })
    }
}

// MARK: - UIImagePickerController
let baseline_vals = ["ay": [0.29882529377937317, 0.18682879209518433, 0.095764830708503723, 0.064638502895832062, 0.043682102113962173, 0.03534390777349472, 0.30295950174331665, 0.28203269839286804],
                     "ee": [0.1122453408,0.1046263104,0.01547330727,0.04486234835,0.2405471156,0.2153886408,0.3041163385,0.3020832638],
                     "oo": [0.1502567939,0.2337069611,0.1084855422,0.850610912,0.01796273235,0.01092089247,0.1611879418,0.1509508441]]

extension FaceScoreViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func calcScore() -> (Double,Double,Int) {
        if shapes.count == 0 {
            return (0.0,0.0,0)
        }
        
        let jawOpen = (shapes[ARFaceAnchor.BlendShapeLocation.jawOpen] as! Double)
        let mouthFunnel = (shapes[ARFaceAnchor.BlendShapeLocation.mouthFunnel] as! Double)
        let mouthClose = (shapes[ARFaceAnchor.BlendShapeLocation.mouthClose] as! Double)
        let mouthPucker = (shapes[ARFaceAnchor.BlendShapeLocation.mouthPucker] as! Double)
        let mouthDimpleLeft = (shapes[ARFaceAnchor.BlendShapeLocation.mouthDimpleLeft] as! Double)
        let mouthDimpleRight = (shapes[ARFaceAnchor.BlendShapeLocation.mouthDimpleRight] as! Double)
        let mouthStretchLeft = (shapes[ARFaceAnchor.BlendShapeLocation.mouthStretchLeft] as! Double)
        let mouthStretchRight = (shapes[ARFaceAnchor.BlendShapeLocation.mouthStretchRight] as! Double)
        
        let actual = [jawOpen, mouthFunnel, mouthClose, mouthPucker, mouthDimpleLeft, mouthDimpleRight, mouthStretchLeft, mouthStretchRight]
        
        print(actual)
        
        return maxError(baseline: baseline_vals[phoneme]!, actual: actual)
    }
    
    func maxError(baseline: [Double], actual: [Double]) -> (Double,Double,Int) {
        var minScore = 1.0
        var err = 0.0
        var maxInd = 0
        
        for i in 0..<baseline.count {
            let c_max = baseline[i] - actual[i]
            let max_possible = (baseline[i] < 0.5) ? 1 - baseline[i] : baseline[i]
            let score = 1 - abs(c_max) / max_possible
            
            if score < minScore {
                minScore = score
                err = c_max
                maxInd = i
            }
        }
        
        return (minScore,err,maxInd)
    }
}
