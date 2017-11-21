import UIKit

class CircleView: UIView {
    let circleLayer: CAShapeLayer!
    var currentStrokeEnd = CGFloat(0.0)
    
    required init?(coder aDecoder: NSCoder) {
        circleLayer = CAShapeLayer()
        super.init(coder: aDecoder)
        self.backgroundColor = UIColor.clear
        
        // Use UIBezierPath as an easy way to create the CGPath for the layer.
        // The path should be the entire circle.
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: frame.size.width / 2.0, y: frame.size.height / 2.0), radius: (frame.size.width - 10)/2, startAngle: CGFloat(-Double.pi/2), endAngle: CGFloat(1.5*Double.pi), clockwise: true)
        
        // Setup the CAShapeLayer with the path, colors, and line width
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.lineWidth = 8.0
        circleLayer.lineCap = "round"
        
        // Don't draw the circle initially
        currentStrokeEnd = 0.005
        circleLayer.strokeEnd = 0.005
        
        // Add the circleLayer to the view's layer's sublayers
        layer.addSublayer(circleLayer)
    }
    
    func animateCircle(percent: CGFloat, duration: TimeInterval) {
        // We want to animate the strokeEnd property of the circleLayer
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        
        // Set the animation duration appropriately
        animation.duration = duration
        
        // Animate from 0 (no circle) to 1 (full circle)
        animation.fromValue = currentStrokeEnd
        animation.toValue = percent
        
        // Do a linear animation (i.e. the speed of the animation stays the same)
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        if percent < 0.35 {
            circleLayer.strokeColor = UIColor.red.cgColor
        } else if percent < 0.8 {
            circleLayer.strokeColor = UIColor.yellow.cgColor
        } else {
            circleLayer.strokeColor = UIColor.green.cgColor
        }
        
        // Set the circleLayer's strokeEnd property to 1.0 now so that it's the
        // right value when the animation ends.
        circleLayer.strokeEnd = percent
        
        // Do the actual animation
        circleLayer.add(animation, forKey: "animateCircle")
        currentStrokeEnd = percent
    }
}
