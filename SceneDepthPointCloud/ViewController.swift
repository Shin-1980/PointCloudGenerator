/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */

import UIKit
import Metal
import MetalKit
import ARKit

final class ViewController: UIViewController, ARSessionDelegate {
    private let isUIEnabled = true
    private let recordButton = UIButton()
    private let takePictureButton = UIButton()
    
    private var isRecording = false
    
    private var taskNum = 0;
    private var completedTaskNum = 0;
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        session.delegate = self
        
        // Set the view to use the default device
        if let view = view as? MTKView {
            view.device = device
            
            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: device, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
            renderer.delegate = self
        }
                
        // UIButton
        recordButton.setTitle("⏺️", for: .normal)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        //recordButton.backgroundColor = .systemBlue
        recordButton.layer.cornerRadius = 5
        recordButton.addTarget(self, action: #selector(onButtonClick), for: .touchUpInside)

        // UIButton
        takePictureButton.setTitle("📷", for: .normal)
        takePictureButton.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        takePictureButton.layer.cornerRadius = 5
        takePictureButton.addTarget(self, action: #selector(onSnapButtonClick), for: .touchUpInside)
        takePictureButton.isHidden = true
                
        let stackView = UIStackView(arrangedSubviews: [
            recordButton, takePictureButton])
        stackView.isHidden = !isUIEnabled
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
         
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        // Run the view's session
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
            
    @objc
    private func onButtonClick(_ sender: UIButton) {
        if (sender != recordButton) {
            return
        }
        updateIsRecording(_isRecording: !isRecording)
    }

    @objc
    private func onSnapButtonClick(_ sender: UIButton) {
        if (sender != takePictureButton) {
            return
        }
        
        if(!renderer.isSnapping){
            renderer.isSnapping = true
            
            if (takePictureButton.backgroundColor == .systemGray){
                takePictureButton.backgroundColor = .systemGray6
                takePictureButton.setTitle("📷", for: .normal)
            }
            else
            {
                takePictureButton.backgroundColor = .systemGray
                takePictureButton.setTitle("📸", for: .normal)

            }
        }
    }

    private func updateIsRecording(_isRecording: Bool) {
        isRecording = _isRecording
        if (isRecording){
            recordButton.setTitle("⏸️", for: .normal)
            takePictureButton.isHidden = false
            renderer.currentFolder = getTimeStr()
            createDirectory(folder: renderer.currentFolder + "/data/in")
        } else {
            recordButton.setTitle("⏺️", for: .normal)
            let url = renderer.savePointCloud()
            takePictureButton.isHidden = true
            showShareSheet(url: url)
        }
        renderer.isRecording = isRecording
    }
    
    // add
    private func showShareSheet(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// update textlabel on tasks start/finish
extension ViewController: TaskDelegate {
    func didStartTask() {
        self.taskNum += 1
    }
    
    func didFinishTask() {
        self.completedTaskNum += 1
    }
}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {
    
}

