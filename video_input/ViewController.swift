//
//  ViewController.swift
//  video_input
//
//  Created by Angad bajwa on 5/29/23.
//

import UIKit
import SwiftUI
import AVFoundation
import CoreML
import CoreMedia
import Vision




class SegmentationResultMLMultiArray {
    let mlMultiArray: MLMultiArray
    let segmentationmapWidthSize: Int
    let segmentationmapHeightSize: Int
    
    init(mlMultiArray: MLMultiArray) {
        self.mlMultiArray = mlMultiArray
        self.segmentationmapWidthSize = mlMultiArray.shape[0].intValue
        self.segmentationmapHeightSize = mlMultiArray.shape[1].intValue
        //print(self.mlMultiArray)
    }
    
    subscript(colunmIndex: Int, rowIndex: Int) -> NSNumber {
        let index = colunmIndex*(segmentationmapHeightSize) + rowIndex
        //print(mlMultiArray[index])
        return mlMultiArray[index]
    }
}


class DrawingSegmentationView: UIView {
    
    static private var colors: [Int32: UIColor] = [0: UIColor(red: 0, green: 1, blue: 0, alpha: 1), 15:UIColor(red: 0, green: 0, blue: 0, alpha: 1)]
    
    func segmentationColor(with index: Int32) -> UIColor {
        if let color = DrawingSegmentationView.colors[index] {
            print("in segmentationcolor")
            return color
        } else {
            let color = UIColor(hue: CGFloat(index) / CGFloat(30), saturation: 1, brightness: 1, alpha: 0.5)
            print(index)
            DrawingSegmentationView.colors[index] = color
            return color
        }
    }
    var segmentationmap: SegmentationResultMLMultiArray? = nil {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        if let ctx = UIGraphicsGetCurrentContext() {
            
            ctx.clear(rect);
            print("Inside draw function")
            guard let segmentationmap = self.segmentationmap
            else { print("Null here")
                return }
            
            let size = self.bounds.size
            let segmentationmapWidthSize = segmentationmap.segmentationmapWidthSize
            let segmentationmapHeightSize = segmentationmap.segmentationmapHeightSize
            let w = size.width / CGFloat(segmentationmapWidthSize)
            let h = size.height / CGFloat(segmentationmapHeightSize)
            
            for j in 0..<segmentationmapHeightSize {
                for i in 0..<segmentationmapWidthSize {
                    let value = segmentationmap[j, i].int32Value

                    let rect: CGRect = CGRect(x: CGFloat(i) * w, y: CGFloat(j) * h, width: w, height: h)

                    let color: UIColor = segmentationColor(with: value)

                    color.setFill()
                    UIRectFill(rect)
                }
            }
        }
    } // end of draw(rect:)

}



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false // Flag for permission
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil // For view dimensions
    @IBOutlet weak var drawingView: DrawingSegmentationView!
    var outputImage : UIImage!
    @IBOutlet weak var outputImageView: UIImageView!
    
    //@IBOutlet weak var drawingView: DrawingSegmentationView!
      
    override func viewDidLoad() {
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    
    // This is for allowing rotation
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        screenRect = UIScreen.main.bounds
        self.previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

        switch UIDevice.current.orientation {
            // Home button on top
            case UIDeviceOrientation.portraitUpsideDown:
                self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
             
            // Home button on right
            case UIDeviceOrientation.landscapeLeft:
                self.previewLayer.connection?.videoOrientation = .landscapeRight
            
            // Home button on left
            case UIDeviceOrientation.landscapeRight:
                self.previewLayer.connection?.videoOrientation = .landscapeLeft
             
            // Home button at bottom
            case UIDeviceOrientation.portrait:
                self.previewLayer.connection?.videoOrientation = .portrait
                
            default:
                break
            }
    }
    
    
    //Checking camera permission
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            // Permission has been granted before
            case .authorized:
                permissionGranted = true
                
            // Permission has not been requested yet
            case .notDetermined:
                requestPermission()
                    
            default:
                permissionGranted = false
            }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func setupCaptureSession() {
        // Camera input back camera
        //guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera,for: .video, position: .back) else { return }
        // front camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .front) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
           
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
                         
        // Preview layer
        screenRect = UIScreen.main.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        previewLayer.connection?.videoOrientation = .portrait
        
        
        let videoOutput = AVCaptureVideoDataOutput()
        guard captureSession.canAddOutput(videoOutput) else {return}
        captureSession.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        
        // Updates to UI must be on main queue
        /*
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
        }
         */
        print("got till here")
         
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("entered_function")
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return  }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else{
            return }
        
        guard let model = try? VNCoreMLModel(for: DeepLabV3(configuration: .init()).model)
        else { return }
        
        let request = VNCoreMLRequest(model: model, completionHandler: visionRequestDidComplete)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer:imageBuffer, options: [:])
        
        do {
            try handler.perform([request])
        }catch {
            print(error)
        }
        
        /*DispatchQueue.main.async {
            print("in here")
            let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
            
            do {
                try handler.perform([request])
            }catch {
                print(error)
            }
            //self.previewLayer.contents = ciImage
            //self.view.layer.addSublayer(self.previewLayer)
        }*/
        
        
        
        
        /*
         DispatchQueue.main.async {
             print("in here")
             self.previewLayer.contents = img
             self.view.layer.addSublayer(self.previewLayer)
         }
         */
         
    }


    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        
        DispatchQueue.main.async { [weak self] in
            if let observations = request.results as? [VNCoreMLFeatureValueObservation],
               let segmentationmap = observations.first?.featureValue.multiArrayValue {
                
                print(segmentationmap)
                
                //Method 1: Using .image
                let segmentationMask = segmentationmap.image(min: 0, max: 1)
                self?.previewLayer.contents = segmentationMask
                
                // Method 2: Using drawingView
                let segmentationResultMLMultiArray = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
                self?.drawingView.segmentationmap = segmentationResultMLMultiArray
                print(segmentationResultMLMultiArray)
                //self?.previewLayer.contents = segmentationResultMLMultiArray
                
                
                
                self?.view.layer.addSublayer(self!.previewLayer)
                print("got here")
            }
        }
        
        //DispatchQueue.main.async { [self] in
               
                    //print(segmentationmap)
                    //let segmentationMask = segmentationmap.image(min: 0, max: 1)
                    //print(segmentationMask)
                    //print(observations)
                    //print(segmentationmap)
                   // let segmentationResultMLMultiArray = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
                    //print("This is segmentationResultMLMultiArray",segmentationResultMLMultiArray)
               
                    
                    /*
                    DispatchQueue.main.async { [weak self] in
                        
                        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
                           let segmentationmap = observations.first?.featureValue.multiArrayValue {
                            //self?.drawingView.segmentationmap = segmentationResultMLMultiArray
                            //let maskImage = segmentationmap.image(min: 0, max: 255)
                            //print(maskImage)
                            //print(segmentationmap)
                            let image: UIImage = segmentationmap.image(min: 0, max: 1)!
                            guard let coreImage = image.cgImage else {
                                return
                            }
                            UIGraphicsBeginImageContext(CGSize(width: coreImage.width, height: coreImage.height))
                            image.draw(in: CGRect(x: Int(0.0), y: Int(0.0), width: coreImage.width, height: coreImage.height))
                            let resultImage = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()
                            
                            print(image)
                            self?.outputImage = image
                            self?.previewLayer.contents = resultImage
                            self?.view.layer.addSublayer(self!.previewLayer)
                            print("got here")
                        }
                        //self.drawingView.segmentationmap = segmentationResultMLMultiArray
                    }
                    
                    //previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    //previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
                    let width =   UIScreen.main.bounds.size.width
                    let height = UIScreen.main.bounds.size.height
                    //let uiImage = segmentationMask?.resizedImage(for: CGSize(width: width, height: height))!
                        //
                    //let segmentationResultMLMultiArray = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
                    //self.drawingView.segmentationmap = segmentationResultMLMultiArray
                    //let uiImage = segmentationMask!
                   

                    //maskInputImage()

                */
            //}
        /*
        DispatchQueue.main.async {
            if let observations = request.results as? [VNCoreMLFeatureValueObservation],
               let maskPixelBuffer = observations.first?.pixelBuffer { return }
            {
                //let segmentationResult = results.first else {return}
                
                // Process the segmentation result
                //let segmentedMask = segmentationResult.pixelBuffer
                //let segmentationResultMLMultiArray = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
                //self.drawingView.segmentationmap = segmentationResultMLMultiArray
                let ciImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
                self.previewLayer.contents = ciImage
                self.view.layer.addSublayer(self.previewLayer)
                print("got here")
                
                //maskInputImage()
                
            }
        }
         */
    }
}


struct HostedViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return ViewController()
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        }
}

struct GradientPoint {
   var location: CGFloat
   var color: UIColor
}
