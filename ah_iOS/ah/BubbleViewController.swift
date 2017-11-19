//
//  BubbleViewController.swift
//  FaceTraking
//
//  Created by Tyler Lacroix on 11/19/17.
//  Copyright © 2017 Toshihiro Goto. All rights reserved.
//

import UIKit
import BubbleTransition


class BubbleViewController: UIViewController, UIViewControllerTransitioningDelegate {
    
    @IBOutlet weak var transitionButton: UIButton!
    
    let transition = BubbleTransition()
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = segue.destination
        controller.transitioningDelegate = self
        controller.modalPresentationStyle = .custom
    }
    
    // MARK: UIViewControllerTransitioningDelegate
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .present
        let pos = transitionButton.convert(transitionButton.center, to: view)
        transition.startingPoint = pos
        
        transition.bubbleColor = transitionButton.backgroundColor!
        return transition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .dismiss
        transition.startingPoint = transitionButton.center
        transition.bubbleColor = transitionButton.backgroundColor!
        return transition
    }
    
}

