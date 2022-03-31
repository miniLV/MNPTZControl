//
//  ViewController.swift
//  IOKitDemo
//
//  Created by Tyrion Liang on 2020/11/3.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    @IBOutlet weak var TiltUpButton: NSButton!
    @IBOutlet weak var PanRightButton: NSButton!
    @IBOutlet weak var PanLeftButton: NSButton!
    @IBOutlet weak var TiltDownButton: NSButton!
    @IBOutlet weak var selectButton: NSPopUpButton!
    
    
    @IBOutlet weak var zoomInButton: NSButton!
    
    @IBOutlet weak var zoomOutButton: NSButton!
    
    @IBOutlet weak var cameraView: NSView!
    @IBAction func clickCameraList(_ sender: Any) {
        
        print("button")
        setupSession()
    }
    let session = AVCaptureSession()
    
    var lastCameraIDsSet = Set<String>()
    let control = CameraPtzController()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let l = AVCaptureVideoPreviewLayer(session: session)
        l.connection?.automaticallyAdjustsVideoMirroring = false
        l.connection?.isVideoMirrored = true
        l.videoGravity = .resizeAspectFill
        return l
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        
        self.setupCamera()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        previewLayer.frame = cameraView.bounds

    }
    
    func setupUI() {
        
        PanLeftButton.tag = 0
        PanRightButton.tag = 1
        TiltUpButton.tag = 2
        TiltDownButton.tag = 3
        zoomOutButton.tag = 4
        zoomInButton.tag = 5
        
        let tap1 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        PanLeftButton.addGestureRecognizer(tap1)
        
        let tap2 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        PanRightButton.addGestureRecognizer(tap2)
        
        let tap3 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        TiltUpButton.addGestureRecognizer(tap3)
        
        let tap4 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        TiltDownButton.addGestureRecognizer(tap4)
        
        let tap5 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        zoomInButton.addGestureRecognizer(tap5)
        
        let tap6 = NSPanGestureRecognizer(target: self, action: #selector(longPress))
        zoomOutButton.addGestureRecognizer(tap6)
        
        
        PanLeftButton.action = #selector(clickPanLeft)
        PanRightButton.action = #selector(clickPanRight)
        TiltUpButton.action = #selector(clickTiltUp)
        TiltDownButton.action = #selector(clickTiltDown)
        zoomInButton.action = #selector(clickZoomIn)
        zoomOutButton.action = #selector(clickZoomOut)
    }
    
    @objc func longPress(sender: NSPanGestureRecognizer) {
        
        guard let button = sender.view else {
            print("button is nil")
            return
        }
        
        if sender.state == .began{
            print("longPress began")
            switch button.tag {
            case 0:
                control.continous(action: [.panLeft])
            case 1:
                control.continous(action: [.panRight])
            case 2:
                control.continous(action: [.tiltUp])
            case 3:
                control.continous(action: [.tiltDown])
            case 4:
                //zoom out
                control.continous(action: [.zoomOut])
            case 5:
                //zoom In
                control.continous(action: [.zoomIn])
                   
            default:
                break
            }
        }
            
        else if sender.state == .ended
        {
            print("longPressStop")
            control.continousEnd()
        }
    }
    
    @objc func clickPanLeft() {
        control.click(action: [.panLeft])
    }

    @objc func clickPanRight() {
        control.click(action: [.panRight])
    }

    @objc func clickTiltUp() {
        control.click(action: [.tiltUp])
    }

    @objc func clickTiltDown() {
        control.click(action: [.tiltDown])
    }

    @objc func clickZoomOut() {
        print("clickZoomOut")
        control.click(action: [.zoomOut])
    }

    @objc func clickZoomIn() {
        print("clickZoomIn")
        control.click(action: [.zoomIn])
    }
    
    var devices:[AVCaptureDevice]  {
        return AVCaptureDevice.devices(for: .video)
    }
    
    func setupCamera() {
        cameraView.wantsLayer = true
        cameraView.layer?.addSublayer(previewLayer)
      
        updateMenu()
        
        selectButton.select(selectButton.itemArray.first)
        setupSession()
        startCameraDiscovery()
    }
    
    func updateMenu() {
        selectButton.removeAllItems()
        for d in devices {
            selectButton.addItem(withTitle: d.localizedName)
        }
    }
    
    func setupSession() {

        if session.isRunning {
            session.stopRunning()
        }
        session.sessionPreset = .low
        for input in session.inputs {
            session.removeInput(input)
        }
        if devices.count > 0 {
            let captureDevice = devices[selectButton.indexOfSelectedItem]
            let deviceInput = try! AVCaptureDeviceInput(device: captureDevice)
            session.addInput(deviceInput)
            session.startRunning()
            
            self.control.setCurrentVideoDevice(uniqueID: captureDevice.uniqueID)
            
            control.fetchAbility(videoDeviceId: captureDevice.uniqueID) { (abilityModel) in
                self.PanLeftButton.isEnabled = abilityModel?.supportPan == true
                self.PanRightButton.isEnabled = abilityModel?.supportPan == true
                self.zoomInButton.isEnabled = abilityModel?.supportZoom == true
                self.zoomOutButton.isEnabled = abilityModel?.supportZoom == true
                self.TiltUpButton.isEnabled = abilityModel?.supportTilt == true
                self.TiltDownButton.isEnabled = abilityModel?.supportTilt == true
            }
        }
    }

}

//Camera plug & unplug.
extension ViewController {
    func startCameraDiscovery() {
        lastCameraIDsSet = Set(AVCaptureDevice.devices(for: .video).compactMap({ $0.uniqueID }))
        NotificationCenter.default.addObserver(self, selector: #selector(onCameraConnected),
                                               name: NSNotification.Name.AVCaptureDeviceWasConnected,
                                               object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(onCameraDisconnected),
                                               name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
                                               object: nil)
    }
    
    @objc func onCameraConnected() {
        notifyCamerasChanged()
    }

    @objc func onCameraDisconnected() {
        notifyCamerasChanged()
    }
    
    private func notifyCamerasChanged() {
        let currentIDs = AVCaptureDevice.devices(for: .video).compactMap({ $0.uniqueID })
        let currentSet: Set<String> = Set(currentIDs)
        if currentSet == lastCameraIDsSet {
            return
        }
        lastCameraIDsSet = currentSet
        cameraDevicesDidChanged()
    }
    
    private func cameraDevicesDidChanged() {
        //auto switch
        updateMenu()
        
        if devices.count > 0{
            
            selectButton.selectItem(at: devices.count - 1)
            setupSession()
        }
    }
}

