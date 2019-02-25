//
//  ViewController.swift
//  RoboSurfer
//
//  Created by Paul Dippold on 10/22/18.
//  Copyright © 2018 Paul Dippold. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO
import DSWaveformImage

class ViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var waveformImage: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var modeSwitch: UISwitch!
    @IBOutlet weak var tableView: UITableView!
    
    let nameArray = ["a", "b", "c", "d", "e", "a unprocessed", "b unprocessed", "c unprocessed", "d unprocessed", "e unprocessed"]
    
    var waveformMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // User finished typing (hit return): hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    func classify(image: UIImage) {
        if let ciImage = CIImage(image: image) {
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                do {
                    let model = try VNCoreMLModel(for: self.waveformMode ? ImageClassifier().model : SpeClassifier().model)
                    
                    let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                        DispatchQueue.main.async {
                            if let results = request.results {
                                let classifications = results as! [VNClassificationObservation]
                                print(classifications)
                                if classifications.isEmpty {
                                    self?.classificationLabel.text = "No matching robocall"
                                } else {
                                    let classification = classifications.first
                                    let confidence = classification!.confidence * 100
                                    self?.classificationLabel.text = "\(classification!.identifier)- \(confidence)%"
                                }
                            }
                        }
                    })
                    
                    try handler.perform([request])
                } catch {
                    print("Failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func createWaveform(index: Int?, url: URL?) {
        let audioURL = url != nil ? url : Bundle.main.url(forResource: nameArray[index!], withExtension: "mp3")!
        DispatchQueue.global(qos: .userInitiated).async {
            if let audioURL = audioURL {
                let waveform = Waveform(audioAssetURL: audioURL)!
                let configuration = WaveformConfiguration(size: CGSize(width: 1000, height: 500),
                                                          color: UIColor.black,
                                                          style: .gradient,
                                                          position: .middle)
                
                let image = UIImage(waveform: waveform, configuration: configuration)
                DispatchQueue.main.async {
                    self.waveformImage.image = image
               //     UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                    self.classify(image: image!)
                }
            }
        }
    }
    
    @IBAction func modeChanged(_ sender: Any) {
        self.waveformMode = modeSwitch.isOn
        self.classificationLabel.text = ""
        self.waveformImage.image = nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.nameArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = self.nameArray[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.classificationLabel.text = ""
        self.waveformImage.image = nil
        if self.waveformMode {
            createWaveform(index: indexPath.row, url: nil)
        } else {
            let path = Bundle.main.path(forResource: self.nameArray[indexPath.row], ofType: "png")
            if let image = UIImage(contentsOfFile: path ?? "") {
                self.waveformImage.image = image
                classify(image: image)
            }
        }
    }
    
}
