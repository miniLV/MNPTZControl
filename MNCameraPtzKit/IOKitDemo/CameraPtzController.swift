//
//  CameraPtzController.swift
//  IOKitDemo
//
//  Created by Tyrion Liang 1 on 2021/3/3.
//

import Cocoa

protocol PTZControlDelegate {
    func stopZoomingTimer()
}

extension CameraPtzController:PTZControlDelegate {
    func stopZoomingTimer() {
        stopTimer()
    }
}

class PTZAbilityModel {
    var supportZoom: Bool = false
    var supportPan: Bool = false
    var supportTilt: Bool = false
    var supportPreset: Bool = false
}

class CameraPtzController: NSObject {
    
    var supportZoom: Bool {
        return control.supportZoom
    }
    var supportPan: Bool {
        return control.supportPan
    }
    var supportTilt: Bool {
        return control.supportTilt
    }
    var supportPreset: Bool {
        return control.supportPreset
    }
    
    var control = CameraIOKitClass()

    var zoomInAbsTimer:Timer?
    var zoomOutAbsTimer:Timer?
  
    override init() {
        super.init()
        control.delegate = self
    }
    
    var abilityModel:PTZAbilityModel?
    
    typealias PTZAbilityBlock = (_ model:PTZAbilityModel?) -> ()
    
    func fetchAbility(videoDeviceId:String, completion : @escaping PTZAbilityBlock) {
        
        PtzQueueFactory.getOperationQueue.async {
            self.setCurrentVideoDevice(uniqueID: videoDeviceId)
            
            DispatchQueue.main.async { [self] in
                completion(abilityModel)
            }
        }
    }
    
    func setupPtzModel(){
        abilityModel = PTZAbilityModel()
        abilityModel?.supportTilt = supportTilt
        abilityModel?.supportZoom = supportZoom
        abilityModel?.supportPan = supportPan
        abilityModel?.supportPreset = supportPreset
    }
    
    func click(action: [PTZAction])  {
        PtzQueueFactory.getOperationQueue.async { [self] in
            control.click(action: action)
        }
    }
    
    func startZoomInTimer() {
        if zoomInAbsTimer != nil {
            return
        }
        zoomInAbsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (_) in
            self.click(action: [.zoomIn])
        })
    }
    
    func startZoomOutTimer() {
        if zoomOutAbsTimer != nil {
            return
        }
        zoomOutAbsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (_) in
            self.click(action: [.zoomOut])
        })
    }
    
    func continous(action: [PTZAction])  {
        
        /**
         If not support rel, zoomIn & zoomOut need to using abs.
         abs need to using timer, call the click method every certain period of time (0.3s),
         it looks the same as a long press
         */
        let supportZoomRel = control.supportZoomRel
        let supportZoomAbs = control.supportZoomAbs
        
        //FIXME: - Need code optimization
        if supportZoomRel {
            //continue
        }else if supportZoomAbs{
            if action.contains(.zoomIn){
                //start zoomIn
                startZoomInTimer()
                return
            }
            if action.contains(.zoomOut){
                //start zoomOut
                startZoomOutTimer()
                return
            }
        }
        
        //rel zoom & pan & zoom
        PtzQueueFactory.getOperationQueue.async { [self] in
            control.continous(action: action)
        }
    }
    
    func stopTimer() {
        if zoomInAbsTimer != nil {
            zoomInAbsTimer?.invalidate()
            zoomInAbsTimer = nil
        }
        
        if zoomOutAbsTimer != nil {
            zoomOutAbsTimer?.invalidate()
            zoomOutAbsTimer = nil
        }
    }
    func continousEnd() {
        stopTimer()
        
        PtzQueueFactory.getOperationQueue.async { [self] in
            control.continousEnd()
        }
    }
    
    func setCurrentVideoDevice(uniqueID:String){
        control = CameraIOKitClass()
        
        PtzQueueFactory.getOperationQueue.async { [self] in
            control.setCurrentVideoDevice(uniqueID: uniqueID)
            
            setupPtzModel()
        }
    }
}

