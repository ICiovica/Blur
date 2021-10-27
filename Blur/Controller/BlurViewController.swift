
import UIKit
import Vision
import CoreImage
import CLTypingLabel
import CoreML

class BlurViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var sliderValue: UISlider!
    @IBOutlet var filterButton: UIButton!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var filterTitle: UILabel!
    @IBOutlet var placeYourAddText: CLTypingLabel!
    @IBOutlet var levelLabel: UILabel!
    
    var delegate = PhotoProcess()
    var inputImage: UIImage?
    var imageRoll = Bundle.main.paths(forResourcesOfType: "png", inDirectory: "Photos")
    var timer = Timer()
    var currentFilter: CIFilter!
    var imageNumber = 1
    var imageIsSelected: Bool = false
    var filterIsChoosed: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(rollImages), userInfo: nil, repeats: true)
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(rollText), userInfo: nil, repeats: true)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(importPhoto))
        navigationItem.leftBarButtonItem?.tintColor = .blue3
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(sharePhoto))
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.tintColor = .blue3
        
        sliderValue.minimumTrackTintColor = .green3
        sliderValue.maximumTrackTintColor = .red2
        sliderValue.thumbTintColor = .whiteDry
        sliderValue.isHidden = true
        levelLabel.isHidden = true
        
        currentFilter = CIFilter(name: "CIPixellate")
        filterTitle.text = "Import your photo and choose a filter from the Editing Tools bellow"
        
        filterButton.adjustButton(filterButton)
        cameraButton.adjustButton(cameraButton)
        saveButton.adjustButton(saveButton)
    }
    
    override func viewDidLayoutSubviews() {
        addBlurRects()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppDelegate.AppUtility.lockOrientation(UIInterfaceOrientationMask.portrait, andRotateTo: UIInterfaceOrientation.portrait)
    }
    
    
    @objc func rollText() {
        if imageIsSelected == false {
            placeYourAddText.textColor = .pink4
            placeYourAddText.text = "Place your add here"
        }
    }
    
    @objc func rollImages() {
        if imageIsSelected == false {
            imageView.image = UIImage(named: String(imageNumber))
            imageNumber += 1
            if imageNumber > 4 {
                imageNumber = 1
            }
        }
    }
    
    @objc func importPhoto() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
        timer.invalidate()
        imageIsSelected = true
        placeYourAddText.isHidden = true
    }
    
    @objc func sharePhoto() {
            guard let img = imageView.image else { return }
            let ac = UIActivityViewController(activityItems: [img], applicationActivities: nil)
            present(ac, animated: true)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let ac = UIAlertController(title: "Save Error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
        } else {
            let ac = UIAlertController(title: "Saved!", message: "Your blurred image has been saved to your photos.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    
    @objc func faceTapped(_ sender: UITapGestureRecognizer) {
        guard let vw = sender.view else { return }
        
        delegate.detectedFaces[vw.tag].blur = !delegate.detectedFaces[vw.tag].blur
        
        if filterIsChoosed == false {
            let ac = UIAlertController(title: nil, message: "Your have to select a filter first.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
        delegate.renderBlurredFaces(inputImage, imageView, filterTitle)
    }
    
    
    func detectFaces() {
        guard let inputImage = inputImage else { return }
        guard let ciImage = CIImage(image: inputImage) else { return }
        
        let request = VNDetectFaceRectanglesRequest { [unowned self] request, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                guard let observations = request.results as? [VNFaceObservation] else { return }
                self.delegate.detectedFaces = Array(zip(observations, [Bool](repeating: false, count: observations.count)))
                self.addBlurRects()
            }
        }
        let handler = VNImageRequestHandler(ciImage: ciImage)
        do {
            try handler.perform([request])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func addBlurRects() {
        // remove any existing face rectangles
        imageView.subviews.forEach { $0.removeFromSuperview() }
        // find the size of the image inside the image view
        let imageRect = imageView.contentClippingRect
        // loop over all the faces that where detected
        for (index, face) in delegate.detectedFaces.enumerated() {
            // pull out the face position
            let boundingBox = face.observation.boundingBox
            // calculate its size
            let size = CGSize(width: boundingBox.width * imageRect.width, height: boundingBox.height * imageRect.height)
            // calculate its position
            var origin = CGPoint(x: boundingBox.minX * imageRect.width, y: (1 - face.observation.boundingBox.minY) * imageRect.height - size.height)
            // offset the position based on the content clipping rect
            origin.y += imageRect.minY
            // place a UIView there
            let vw = UIView(frame: CGRect(origin: origin, size: size))
            // store its face number as its tag
            vw.tag = index
            // store its border color and add it
            if delegate.imageDescription == "Kids" {
                vw.layer.borderColor = UIColor.red2.cgColor
            }
            else if delegate.imageDescription == "Adults" {
                vw.layer.borderColor = UIColor.green4.cgColor
            }
            vw.layer.borderWidth = 2
            imageView.addSubview(vw)
            
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(faceTapped))
            
            vw.addGestureRecognizer(recognizer)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // pull out the image that was selected
        guard let image = info[.editedImage] as? UIImage else { return }
        // save it in our image view and property
        imageView.image = image
        inputImage = image
        // hide the image picker
        dismiss(animated: true)
        // detect faces
        self.detectFaces()
        delegate.analyzeImage(image: image)
        timer.invalidate()
        imageIsSelected = true
        placeYourAddText.isHidden = true
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func imageIsNotSelected() {
        let ac = UIAlertController(title: nil, message: "Your have to import a photo first.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    func setFilter(action: UIAlertAction) {
        guard inputImage != nil else { return }
        guard let actionTitle = action.title else { return }
        
        currentFilter = CIFilter(name: actionTitle)
        filterTitle.text = "\(actionTitle)"
        filterIsChoosed = true
        sliderValue.isHidden = false
        levelLabel.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    @IBAction func pixelValueTapped(_ sender: UISlider) {
        delegate.adjustPixellation = sender.value
        delegate.renderBlurredFaces(inputImage, imageView, filterTitle)
    }
    
    @IBAction func changeFilterSelectionOne(_ sender: UIButton) {
        if imageIsSelected {
            let ac = UIAlertController(title: "Choose filter", message: nil, preferredStyle: .actionSheet)
            ac.addAction(UIAlertAction(title: "CIPixellate", style: .default, handler: setFilter))
            ac.addAction(UIAlertAction(title: "CIBloom", style: .default, handler: setFilter))
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let popoverController = ac.popoverPresentationController {
                popoverController.sourceView = sender
                popoverController.sourceRect = sender.bounds
            }
            present(ac, animated: true)
        } else {
            imageIsNotSelected()
        }
    }
    
    @IBAction func savePhoto(_ sender: UIButton) {
        if imageIsSelected {
            guard let image = imageView.image else {
                imageIsNotSelected()
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_: didFinishSavingWithError:contextInfo:)), nil)
        } else {
            imageIsNotSelected()
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        self.present(imagePicker, animated: true, completion: nil)
    }
}
