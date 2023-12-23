//
//  SmudgeDrawingView.swift
//  Inpaint
//
//  Created by wudijimao on 2023/12/1.
//

import Foundation
import UIKit

class SmudgeDrawingView: UIView {

    private var path: UIBezierPath = UIBezierPath()
    private var touchPoints: [CGPoint] = []
    var smudgeColor: UIColor = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 0.5) // 默认为半透明的淡蓝色
    var exportLineColor: UIColor = .white // 涂抹部分导出时的颜色
    var exportBackgroundColor: UIColor = .black // 未涂抹部分导出时的颜色
    var brushSize: CGFloat = 20.0 // 默认笔刷大小


    init() {
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGesture.maximumNumberOfTouches = 1
        self.addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // 计算绘制区域的边界
    public var drawBounds: [CGRect] {
        get {
            if path.isEmpty {
                return []
            }
            var rect = path.bounds
            rect = CGRect(x: rect.origin.x * UIScreen.main.scale, y: rect.origin.y * UIScreen.main.scale, width: rect.size.width * UIScreen.main.scale, height: rect.size.height * UIScreen.main.scale)
            return [rect]
        }
    }
    
    @objc func panGestureAction(_ sender: UIPanGestureRecognizer) {
        let touchPoint = sender.location(in: self)
        
        switch sender.state {
        case .began:
            _touchesBegan(touchPoint: touchPoint)
        case .changed:
            _touchesMoved(touchPoint: touchPoint)
        case .ended:
            _touchesEnded(touchPoint: touchPoint)
        case .cancelled:
            touchPoints.removeAll()
            path.removeAllPoints()
            self.setNeedsDisplay()
        default:
            break
        }
    }
    
    @inline(__always)
    func _touchesBegan(touchPoint: CGPoint) {
        path.move(to: touchPoint)
        touchPoints.append(touchPoint)
    }
    
    @inline(__always)
    func _touchesMoved(touchPoint: CGPoint) {
        // 计算上一个点和当前点的中间点
        let previousPoint = touchPoints.last ?? touchPoint
        let middlePoint = CGPoint(x: (touchPoint.x + previousPoint.x) / 2.0, y: (touchPoint.y + previousPoint.y) / 2.0)

        // 添加二次贝塞尔曲线，使曲线更平滑
        path.addQuadCurve(to: middlePoint, controlPoint: previousPoint)
        touchPoints.append(touchPoint)

        // 重绘当前触摸点附近的区域
        let redrawRect = CGRect(x: touchPoint.x - brushSize * 2, y: touchPoint.y - brushSize * 2,
                                width: brushSize * 4, height: brushSize * 4)
        setNeedsDisplay(redrawRect)
    }
    
    // 处理触摸结束事件
    @inline(__always)
    func _touchesEnded(touchPoint: CGPoint) {
        // 添加最后一个点到路径中
        if let lastPoint = touchPoints.last {
            let middlePoint = CGPoint(x: (touchPoint.x + lastPoint.x) / 2.0, y: (touchPoint.y + lastPoint.y) / 2.0)
            path.addQuadCurve(to: middlePoint, controlPoint: lastPoint)
        }

        // 清除触摸点，为下一次绘制做准备
        touchPoints.removeAll()

        // 重绘视图以显示最终的绘图
        self.setNeedsDisplay()
    }

    // 绘制方法
    override func draw(_ rect: CGRect) {
        smudgeColor.setStroke()
        path.lineWidth = brushSize
        path.lineCapStyle = .round // 设置线帽为圆形，使曲线封闭部分为圆形
        path.stroke()
    }

    // 导出为灰度图像
    func exportAsGrayscaleImage() -> UIImage? {
        let screenScale = UIScreen.main.scale

        // 放大后的尺寸
        let scaledSize = CGSize(width: self.bounds.size.width * screenScale, height: self.bounds.size.height * screenScale)

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }


        // 绘制背景
        exportBackgroundColor.setFill()
        context.fill(CGRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height))

        // 调整路径尺寸
        let scaledPath = UIBezierPath(cgPath: path.cgPath)
        scaledPath.apply(CGAffineTransform(scaleX: screenScale, y: screenScale))
        exportLineColor.setStroke()
        scaledPath.lineWidth = brushSize * screenScale // 调整线宽
        scaledPath.lineCapStyle = .round
        scaledPath.stroke()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    
    public func clean() {
        path = UIBezierPath()
        self.setNeedsDisplay()
    }
}
