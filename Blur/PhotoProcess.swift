

import UIKit
import Vision
import CoreImage
import CLTypingLabel
import CoreML

struct PhotoProcess {
    
    var imageDescription: String?
    var detectedFaces = [(observation: VNFaceObservation, blur: Bool)]()
    var adjustPixellation: Float = 25
    
    mutating func analyzeImage(image: UIImage?) {
        guard let photo = image else { return }
        guard let buffer = photo.buffer(from: photo) else { return }
        
        do {
            let config = MLModelConfiguration()
            let model = try KidsAdults(configuration: config)
            let input = KidsAdultsInput(image: buffer)
            
            let output = try model.prediction(input: input)
            let text = output.classLabel
            imageDescription = text
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func renderBlurredFaces(_ inputImage: UIImage?, _ imageView: UIImageView, _ filterTitle: UILabel) {
        guard let currentUIImage = inputImage else { return }
        guard let currentCGImage = currentUIImage.cgImage else { return }
        guard let currentTitle = filterTitle.text else { return }
        
        let currentCIImage = CIImage(cgImage: currentCGImage)
        let filter = CIFilter(name: currentTitle)
        
        if currentTitle == "CIPixellate" {
            filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
            filter?.setValue(adjustPixellation, forKey: kCIInputScaleKey)
        } else if currentTitle == "CIBloom" {
            filter?.setValue(currentCIImage, forKey: kCIInputImageKey)
            filter?.setValue(adjustPixellation * 10, forKey: kCIInputIntensityKey)
            filter?.setValue(adjustPixellation, forKey: kCIInputRadiusKey)
        }
        
        guard let outputImage = filter?.outputImage else { return }
        
        let blurredImage = UIImage(ciImage: outputImage)
        // prepare to render a new image at the full size we need
        let renderer = UIGraphicsImageRenderer(size: currentUIImage.size)
        // commence rendering
        let result = renderer.image { ctx in
            // draw the original image first
            currentUIImage.draw(at: .zero)
            // create an empty clipping path that will hold our faces
            let path = UIBezierPath()
            
            for face in detectedFaces {
                // if this face ought to be blurred
                if face.blur {
                    // calculate the position of this face in image coordinates
                    let boundingBox = face.observation.boundingBox
                    let size = CGSize(width: boundingBox.width * currentUIImage.size.width, height: boundingBox.size.height * currentUIImage.size.height)
                    let origin = CGPoint(x: boundingBox.minX * currentUIImage.size.width, y: (1 - face.observation.boundingBox.minY) * currentUIImage.size.height - size.height)
                    let rect = CGRect(origin: origin, size: size)
                    // convert those coordinates to a path, and add it to our clipping path
                    let miniPath = UIBezierPath(rect: rect)
                    path.append(miniPath)
                }
                
            }
            // if our clipping path isn't empty, activate it now then draw the blurred image with that mask
            if !path.isEmpty {
                path.addClip()
                blurredImage.draw(at: .zero)
            }
        }
        // show the result in our image view
        imageView.image = result
    }
}

extension UIImage {
    
    func buffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}









