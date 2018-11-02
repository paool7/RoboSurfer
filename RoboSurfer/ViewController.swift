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
    @IBOutlet weak var recordingURL: UITextField!

    var recordingArray: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getRecordings()
    }
    @IBAction func setURL(_ sender: UITextField) {
        self.downloadAudio(url: sender.text!)
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
                    let model = try VNCoreMLModel(for: ImageClassifier().model)
                    
                    let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                        DispatchQueue.main.async {
                            if let results = request.results {
                                let classifications = results as! [VNClassificationObservation]
                                print(classifications)
                                if classifications.isEmpty {
                                    self?.classificationLabel.text = "No matching robocall"
                                } else {
                                    let classification = classifications.first
                                    
                                    self?.classificationLabel.text = "\(classification!.identifier)- \(classification!.confidence)"
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
        let audioURL = url != nil ? url : Bundle.main.url(forResource: recordingArray[index!], withExtension: "mp3")!
        
        if let audioURL = audioURL {
            let waveform = Waveform(audioAssetURL: audioURL)!
            let configuration = WaveformConfiguration(size: CGSize(width: 1000, height: 500),
                                                      color: UIColor.black,
                                                      style: .gradient,
                                                      position: .middle)
            
            DispatchQueue.global(qos: .userInitiated).async {
                let image = UIImage(waveform: waveform, configuration: configuration)
                DispatchQueue.main.async {
                    self.waveformImage.image = image
//                    UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                    self.classify(image: image!)
                }
            }
        }
    }
    
    func downloadAudio(url: String) {
        if let audioUrl = NSURL(string: url) {
            let documentsDirectoryURL =  FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            
            let path = documentsDirectoryURL.appendingPathComponent(audioUrl.lastPathComponent ?? "audio.mp3")
            
            if !FileManager().fileExists(atPath: path.path)  {
                URLSession.shared.downloadTask(with: audioUrl as URL, completionHandler: { (location, response, error) -> Void in
                    guard let location = location, error == nil else { return }
                    do {
                        try FileManager().moveItem(at: location, to: path)
                        self.createWaveform(index: 0, url: path)
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }).resume()
            }
        }
    }
    
    func getRecordings() {
        let enumerator = FileManager.default.enumerator(atPath: Bundle.main.resourcePath!)
        var filePaths: [String] = []
        
        while let filePath = enumerator?.nextObject() as? String {
            
            if URL(fileURLWithPath: filePath).pathExtension == "mp3" {
                let name = filePath.replacingOccurrences(of: ".mp3", with: "")
                filePaths.append(name)
            }
        }
        recordingArray = filePaths
        
//        for i in 0..<recordingArray.count {
            createWaveform(index: 2, url: nil)
//        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.recordingArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = self.recordingArray[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        createWaveform(index: indexPath.row, url: nil)
    }

}
