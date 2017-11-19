//
//  InstructionsVCViewController.swift
//  FaceTraking
//
//  Created by Darryl Murray on 2017-11-18.
//  Copyright © 2017 Toshihiro Goto. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class InstructionsViewController: ModalViewController {

    
    @IBOutlet weak var tipsText: UITextView!
    var playerVC: AVPlayerViewController!
    internal var vowel: String!
    var phoneme = "oo"
    let tips = [
        "ay":"""
        •    Open your mouth as wide as possible vertically and horizontally
        
        •    Apply impact on the pit of your stomach
        
        •    Let the air out
        
        •    Feel the vibration on your throat
        """,
        "eh": """
        •    Open your mouth as wide as possible horizontally, as if you are smiling with your mouth slightly open
        
        •    Apply a small impact on the pit of your stomach
        
        •    Let the air out
        
        •    Feel the vibration on your throat

        """,
        "ee": """
        •    Open your mouth as wide as possible horizontally.
        
        •    Close your teeth
        
        •    Apply a small impact on the pit of your stomach
        
        •    Let the air out
        
        •    Feel the vibration on your throat
        """,
        "oh": """
        •    Open your mouth as wide as possible vertically.
        
        •    Make an “O” shape with your mouth
        
        •    Apply a small impact on the pit of your stomach
        
        •    Let the air out
        
        •    Feel the vibration on your throat
        """,
        "oo": """
        •    Close your teeth
        
        •    Stick your lips out, as you are kissing
        
        •    Apply a small impact on the pit of your stomach
        
        •    Let the air out
        
        •    Feel the vibration on your throat
        """
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // vowel
        var fileName: String!
        switch vowel {
        case "a":
            fileName = "Ah"
            phoneme = "ay"
        case "e":
            fileName = "Eh"
        case "i":
            fileName = "Ee(i)"
            phoneme = "ee"
        case "o":
            fileName = "Oh"
        case "u":
            fileName = "oo(u)"
            phoneme = "oo"
        default:
            break   // Fuck it.
        }
        
        tipsText.text = tips[phoneme]
        
        // Get the video file URL
        let url = Bundle.main.url(forResource: fileName, withExtension: "mp4")!
        
        print(url)

        // Swap out the playing item, or create a new player
        if let play = playerVC.player {
            play.replaceCurrentItem(with: AVPlayerItem(url: url))
        } else {
            playerVC.player = AVPlayer(url: url)
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // When the child video player is instantiated, get its reference
        if (segue.identifier == "videoSegue") {
            playerVC = segue.destination as! AVPlayerViewController
        } else if (segue.identifier == "faceSegue") {
            let faceVC = segue.destination as! FaceScoreViewController
            faceVC.phoneme = phoneme
        }
    }
}
