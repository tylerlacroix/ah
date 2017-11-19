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

class InstructionsVCViewController: UIViewController {

    @IBOutlet weak var playerEmbed: UIView!
    var playerVC: AVPlayerViewController!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let url = Bundle.main.url(forResource: "Ah", withExtension: "mp4")!;
        let asset = AVAsset(url: url);
        let assetKeys = [
            "playable"
        ]
        // Create a new AVPlayerItem with the asset and an
        // array of asset keys to be automatically loaded
        let playerItem = AVPlayerItem(asset: asset,
                                  automaticallyLoadedAssetKeys: assetKeys)
        
        // Register as an observer of the player item's status property
//        playerItem.addObserver(self,
//                               forKeyPath: #keyPath(AVPlayerItem.status),
//                               options: [.old, .new],
//                               context: &playerItemContext)
        
        // Associate the player item with the player
        let player = AVPlayer(url: url) // AVPlayer(playerItem: playerItem)
        if let play = playerVC.player {
            play.replaceCurrentItem(with: AVPlayerItem(url: url));
        } else {
            playerVC.player = player;
        }
        
        
//        play.replaceCurrentItem(with: "ah.mov");
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        print(playerVC.videoBounds)
//        let avPlayerLayer =
        
        //view.layer.addSublayer(playerVC.view.layer)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "videoSegue") {
            playerVC = segue.destination as! AVPlayerViewController;
        }
    }

    
}
