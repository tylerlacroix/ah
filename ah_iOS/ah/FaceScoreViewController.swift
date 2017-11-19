//
//  FaceScoreViewController.swift
//  FaceTraking
//
//  Created by Tyler Lacroix on 11/18/17.

import UIKit
import ARKit

class FaceScoreViewController: UIViewController, OEEventsObserverDelegate, ARSCNViewDelegate, ARSessionDelegate {
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
    var timer: Timer!
    
    @IBOutlet var stopButton:UIButton!
    @IBOutlet var startButton:UIButton!
    @IBOutlet var suspendListeningButton:UIButton!
    @IBOutlet var resumeListeningButton:UIButton!
    @IBOutlet var statusTextView:UITextView!
    @IBOutlet var heardTextView:UITextView!
    @IBOutlet var pocketsphinxDbLabel:UILabel!
    @IBOutlet var fliteDbLabel:UILabel!
    
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
        
        let firstLanguageArray = [
            "ee"/*,
             "ah",
             "ee",
             "eh",
             "eye",
             "oh",
             "oo",
             "you",
             "hell"*/]
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
            }
            catch {
                print("Error: it wasn't possible to set the shared instance to active: \"\(error)\"")
            }
            
            // OEPocketsphinxController.sharedInstance().verbosePocketSphinx = true // If you encounter any issues, set this to true to get verbose logging output from OEPocketsphinxController to either diagnose your issue or provide information when asking for help at the forums.
            
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            }
            startDisplayingLevels()
            
            // Here is some UI stuff that has nothing specifically to do with OpenEars implementation
            self.startButton.isHidden = true
            self.stopButton.isHidden = true
            self.suspendListeningButton.isHidden = true
            self.resumeListeningButton.isHidden = true
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
    
    
    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) {
        print(recognitionScore)
        let score = String(Int(100/(1+pow(M_E, (-0.0002*Double(recognitionScore)!-4.4985)))))
        print("Local callback: The received hypothesis is \(hypothesis!) with a score of \(score) and an ID of \(utteranceID!)")
        
        self.heardTextView.text = "Heard: \"\(hypothesis!)\" score: \"\(score)\""
        
        // This is how to use an available instance of OEFliteController. We're going to repeat back the command that we heard with the voice we've chosen.
        self.fliteController.say(_:"You said \(hypothesis!)", with:self.slt)
    }
    // An optional delegate method of OEEventsObserver which informs that the interruption to the audio session ended.
    func audioSessionInterruptionDidEnd() {
        print("Local callback:  AudioSession interruption ended.") // Log it.
        self.statusTextView.text = "Status: AudioSession interruption ended." // Show it in the status box.
        // We're restarting the previously-stopped listening loop.
        if(!OEPocketsphinxController.sharedInstance().isListening){
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the audio input became unavailable.
    func audioInputDidBecomeUnavailable() {
        print("Local callback:  The audio input has become unavailable") // Log it.
        self.statusTextView.text = "Status: The audio input has become unavailable" // Show it in the status box.
        
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeUnavailable: \(stopListeningError)")
            }
        }
        
        // An optional delegate method of OEEventsObserver which informs that the unavailable audio input became available again.
        func audioInputDidBecomeAvailable() {
            print("Local callback: The audio input is available") // Log it.
            self.statusTextView.text = "Status: The audio input is available" // Show it in the status box.
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        }
        // An optional delegate method of OEEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
        func audioRouteDidChange(toRoute newRoute: String!) {
            print("Local callback: Audio route change. The new audio route is \(newRoute)") // Log it.
            self.statusTextView.text = "Status: Audio route change. The new audio route is \(newRoute)"// Show it in the status box.
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
        self.statusTextView.text = "Status: Pocketsphinx started." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is now listening for speech.
    func pocketsphinxDidStartListening() {
        
        print("Local callback: Pocketsphinx is now listening.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx is now listening." // Show it in the status box.
        
        self.startButton.isHidden = true // React to it with some UI changes.
        self.stopButton.isHidden = false
        self.suspendListeningButton.isHidden = false
        self.resumeListeningButton.isHidden = true
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
    func pocketsphinxDidDetectSpeech() {
        print("Local callback: Pocketsphinx has detected speech.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has detected speech." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance.
    // This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between
    // this method being called and the hypothesis being returned.
    func pocketsphinxDidDetectFinishedSpeech() {
        print("Local callback: Pocketsphinx has detected a second of silence, concluding an utterance.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has detected finished speech." // Show it in the status box.
    }
    
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx has exited its recognition loop, most
    // likely in response to the OEPocketsphinxController being told to stop listening via the stopListening method.
    func pocketsphinxDidStopListening() {
        print("Local callback: Pocketsphinx has stopped listening.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has stopped listening." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
    // Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
    // in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to suspend recognition via the suspendRecognition method.
    func pocketsphinxDidSuspendRecognition() {
        print("Local callback: Pocketsphinx has suspended recognition.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has suspended recognition." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
    // having been suspended it is now resuming.  This can happen as a result of Flite speech completing
    // on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to resume recognition via the resumeRecognition method.
    func pocketsphinxDidResumeRecognition() {
        print("Local callback: Pocketsphinx has resumed recognition.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has resumed recognition." // Show it in the status box.
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
        self.statusTextView.text = "Status: Flite has started speaking." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Flite is finished speaking, most likely to be useful if debugging a
    // complex interaction between sound classes.
    func fliteDidFinishSpeaking() {
        print("Local callback: Flite has finished speaking") // Log it.
        self.statusTextView.text = "Status: Flite has finished speaking." // Show it in the status box.
    }
    
    func pocketSphinxContinuousSetupDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Setting up the continuous recognition loop has failed for the reason \(reasonForFailure), please turn on OELogging.startOpenEarsLogging() to learn more.") // Log it.
        self.statusTextView.text = "Status: Not possible to start recognition loop." // Show it in the status box.
    }
    
    func pocketSphinxContinuousTeardownDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Tearing down the continuous recognition loop has failed for the reason %, please turn on [OELogging startOpenEarsLogging] to learn more.", reasonForFailure) // Log it.
        self.statusTextView.text = "Status: Not possible to cleanly end recognition loop." // Show it in the status box.
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
    
    
    /** The user prompt to get mic permissions, or a check of the mic permissions, has completed with a true or a false result  (will only be returned on iOS7 or later).*/
    
    func micPermissionCheckCompleted(withResult: Bool) {
        if(withResult) {
            
            self.restartAttemptsDueToPermissionRequests += 1
            if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions) { // If we get here because there was an attempt to start which failed due to lack of permissions, and now permissions have been requested and they returned true, we restart exactly once with the new permissions.
                
                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
                }
                
                self.startupFailedDueToLackOfPermissions = false
            }
        }
        
    }
    
    
    
    // This is not OpenEars-specific stuff, just some UI behavior
    
    @IBAction func suspendListeningButtonAction() { // This is the action for the button which suspends listening without ending the recognition loop
        
        
        OEPocketsphinxController.sharedInstance().suspendRecognition()
        
        self.startButton.isHidden = true
        self.stopButton.isHidden = false
        self.suspendListeningButton.isHidden = true
        self.resumeListeningButton.isHidden = false
    }
    
    @IBAction func resumeListeningButtonAction() { // This is the action for the button which resumes listening if it has been suspended
        OEPocketsphinxController.sharedInstance().resumeRecognition()
        
        self.startButton.isHidden = true
        self.stopButton.isHidden = false
        self.suspendListeningButton.isHidden = false
        self.resumeListeningButton.isHidden = true
    }
    
    @IBAction func stopButtonAction() { // This is the action for the button which shuts down the recognition loop.
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(stopListeningError)")
            }
        }
        self.startButton.isHidden = false
        self.stopButton.isHidden = true
        self.suspendListeningButton.isHidden = true
        self.resumeListeningButton.isHidden = true
    }
    
    @IBAction func startButtonAction() { // This is the action for the button which starts up the recognition loop again if it has been shut down.
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
        self.startButton.isHidden = true
        self.stopButton.isHidden = false
        self.suspendListeningButton.isHidden = false
        self.resumeListeningButton.isHidden = true
    }
    
    @IBAction func banana() {
        OEPocketsphinxController.sharedInstance().vadThreshold = 3.5
        OEPocketsphinxController.sharedInstance().secondsOfSilenceToDetect = 0.1
        
    }
    
    // What follows are not OpenEars methods, just an approach for level reading
    // that I've included with this sample app. My example implementation does make use of two OpenEars
    // methods:    the pocketsphinxInputLevel method of OEPocketsphinxController and the fliteOutputLevel
    // method of OEFliteController.
    //
    // The example is meant to show one way that you can read those levels continuously without locking the UI,
    // by using an NSTimer, but the OpenEars level-reading methods
    // themselves do not include multithreading code since I believe that you will want to design your own
    // code approaches for level display that are tightly-integrated with your interaction design and the
    // graphics API you choose.
    //
    // Please note that if you use my sample approach, you should pay attention to the way that the timer is always stopped in
    // dealloc. This should prevent you from having any difficulties with deallocating a class due to a running NSTimer process.
    
    func startDisplayingLevels() { // Start displaying the levels using a timer
        if(self.timer != nil) {
            self.timer.invalidate()
        }
        // start the timer
        self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateLevelsUI), userInfo: nil, repeats: true)
        
    }
    
    
    
    @objc func updateLevelsUI() { // And here is how we obtain the levels.  This method includes the actual OpenEars methods and uses their results to update the UI of this view controller.
        
        self.pocketsphinxDbLabel.text = "Pocketsphinx Input level: \(OEPocketsphinxController.sharedInstance().pocketsphinxInputLevel)"//pocketsphinxInputLevel is an OpenEars method of the class OEPocketsphinxController.
        
        if(self.fliteController.speechInProgress) {
            self.fliteDbLabel.text = "Flite Output level: \(self.fliteController.fliteOutputLevel)" // fliteOutputLevel is an OpenEars method of the class OEFliteController.
        }
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

extension FaceScoreViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
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
