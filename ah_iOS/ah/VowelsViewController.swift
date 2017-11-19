//
//  VowelsViewController.swift
//  FaceTraking
//
//  Created by Darryl Murray on 2017-11-19.
//  Copyright © 2017 Toshihiro Goto. All rights reserved.
//

import UIKit

class VowelsViewController: UIViewController {

    var selectedVowel: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let vowel = sender as? String else {
            return
        }
        
        let dest = segue.destination as! InstructionsViewController
        dest.vowel = vowel
    }

    @IBAction func transitionVowel(_ sender: UIButton) {
        let vowel = sender.titleLabel?.text
        performSegue(withIdentifier: "InstructionsSegue", sender: vowel)
    }
}
