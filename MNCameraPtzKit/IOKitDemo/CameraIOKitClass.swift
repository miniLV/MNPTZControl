//
//  TestAgain.swift
//  IOKitDemo
//
//  Created by Tyrion Liang on 2020/11/4.
//

import Foundation
import IOKit
import IOKit.usb
import IOKit.serial
import AVFoundation

let MOVE_UP:Int8 = 1
let MOVE_DOWN:Int8 = -1
let MOVE_LEFT:Int8 = 1
let MOVE_RIGHT:Int8 = -1
let ZOOM_IN:Int8 = 1
let ZOOM_OUT:Int8 = -1
let ZOOM_STOP:Int8 = 0

struct PTZAction: OptionSet {
    let rawValue: Int

    static let panLeft  = PTZAction(rawValue: 1)  //1 << 0
    static let panRight = PTZAction(rawValue: 2)  //1 << 1
    static let tiltUp   = PTZAction(rawValue: 4)  //1 << 2
    static let tiltDown = PTZAction(rawValue: 8)  //1 << 3
    static let zoomIn   = PTZAction(rawValue: 32) //1 << 4
    static let zoomOut  = PTZAction(rawValue: 64)//1 << 5
}

let UVC_RC_UNDEFINED:UInt8 = 0x00
let UVC_SET_CUR:UInt8 = 0x01
let UVC_GET_CUR:UInt8 = 0x81
let UVC_GET_MIN:UInt8 = 0x82
let UVC_GET_MAX:UInt8 = 0x83
let UVC_GET_RES:UInt8 = 0x84
let UVC_GET_LEN:UInt8 = 0x85
let UVC_GET_INFO:UInt8 = 0x86
let UVC_GET_DEF:UInt8 = 0x87

/** Camera terminal control selector (A.9.4) */
let UVC_CT_CONTROL_UNDEFINED:UInt16 = 0x00
let UVC_CT_SCANNING_MODE_CONTROL:UInt16 = 0x01
let UVC_CT_AE_MODE_CONTROL:UInt16 = 0x02
let UVC_CT_AE_PRIORITY_CONTROL:UInt16 = 0x03
let UVC_CT_EXPOSURE_TIME_ABSOLUTE_CONTROL:UInt16 = 0x04
let UVC_CT_EXPOSURE_TIME_RELATIVE_CONTROL:UInt16 = 0x05
let UVC_CT_FOCUS_ABSOLUTE_CONTROL:UInt16 = 0x06
let UVC_CT_FOCUS_RELATIVE_CONTROL:UInt16 = 0x07
let UVC_CT_FOCUS_AUTO_CONTROL:UInt16 = 0x08
let UVC_CT_IRIS_ABSOLUTE_CONTROL:UInt16 = 0x09
let UVC_CT_IRIS_RELATIVE_CONTROL:UInt16 = 0x0a
let UVC_CT_ZOOM_ABSOLUTE_CONTROL:UInt16 = 0x0b
let UVC_CT_ZOOM_RELATIVE_CONTROL:UInt16 = 0x0c
let UVC_CT_PANTILT_ABSOLUTE_CONTROL:UInt16 = 0x0d
let UVC_CT_PANTILT_RELATIVE_CONTROL:UInt16 = 0x0e
let UVC_CT_ROLL_ABSOLUTE_CONTROL:UInt16 = 0x0f
let UVC_CT_ROLL_RELATIVE_CONTROL:UInt16 = 0x10
let UVC_CT_PRIVACY_CONTROL:UInt16 = 0x11
let UVC_CT_FOCUS_SIMPLE_CONTROL:UInt16 = 0x12
let UVC_CT_DIGITAL_WINDOW_CONTROL:UInt16 = 0x13
let UVC_CT_REGION_OF_INTEREST_CONTROL:UInt16 = 0x14

extension CameraIOKitClass{
    //Public function
    func click(action: [PTZAction])  {
        ptzEventHandle(actions: action, isContinuous: false)
    }
    
    func continous(action: [PTZAction])  {
        ptzEventHandle(actions: action, isContinuous: true)
    }
    
    func continousEnd() {
        setContinuousZoomRelStop()
        setContinuousPantiltRelStop()
    }
    
    func continuousZoomIn() {
        setContinuousZoomRelStart(x: ZOOM_IN)
    }
    
    func continuousZoomOut() {
        setContinuousZoomRelStart(x: ZOOM_OUT)
    }
 
    func ptzEventHandle(actions: [PTZAction], isContinuous:Bool)  {
        
        if actions.contains(.zoomIn) {
            isContinuous ? continuousZoomIn() : zoomIn()
        }
        
        if actions.contains(.zoomOut) {
            isContinuous ? continuousZoomOut() : zoomOut()
        }
        
        var pan:Int8 = 0
        var tilt:Int8 = 0
        if actions.contains(.panLeft){
            pan = MOVE_LEFT
        }
        if actions.contains(.panRight) {
            pan = MOVE_RIGHT
        }
        if actions.contains(.tiltUp){
            tilt = MOVE_UP
        }
        if actions.contains(.tiltDown) {
            tilt = MOVE_DOWN
        }
        
        if !supportMoveRel {
            //don't support rel move.
            return
        }
        
        if isContinuous {
            setContinuousPantiltRelStart(x: pan, y: tilt)
        } else{
            setPantiltRel(x: pan, y: tilt)
        }
    }
}

//MARK: private - device control
extension CameraIOKitClass{
    
    func openDevice() -> Bool {
        var configPtr:IOUSBConfigurationDescriptorPtr?
        var score:Int32 = 0
        print("start, plugInInterfacePtrPtr = \(String(describing: plugInInterfacePtrPtr))")
        
        let plugInInterfaceResult = IOCreatePlugInInterfaceForService(
            currentDevice,
            kIOUSBDeviceUserClientTypeID,
            kIOCFPlugInInterfaceID,
            &plugInInterfacePtrPtr,
            &score)
        
        print("end, plugInInterfacePtrPtr = \(String(describing: plugInInterfacePtrPtr))")
        
        guard plugInInterfaceResult == kIOReturnSuccess,
              let plugInInterface = plugInInterfacePtrPtr?.pointee?.pointee else {
            print("Unable to get Plug-In Interface")
            return false
        }
        
        let deviceInterfaceResult = withUnsafeMutablePointer(to: &deviceInterfacePtrPtr) {
            $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) {
                plugInInterface.QueryInterface(
                    plugInInterfacePtrPtr,
                    CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                    $0)
            }
        }
        
        // find device
        guard deviceInterfaceResult == kIOReturnSuccess,
              let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            print("Unable to get Device Interface")
            return false
        }
        
        //checkSupportZoomAbs()
        
        // open device
        var ret = deviceInterface.USBDeviceOpen(deviceInterfacePtrPtr)
        guard (ret == kIOReturnSuccess) else {
            print("open fail")
            return false
        }
        
        // ret==0, open success.
        ret = deviceInterface.GetConfigurationDescriptorPtr(deviceInterfacePtrPtr, 0, &configPtr)
        guard let config = configPtr?.pointee else {
            print("get config ptr fail")
            return false
        }
        guard config.bLength > 0 else {
            print("config.bLength == 0")
            return false
        }
        
        return true
    }
    
    func closeDevice()  {
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            print("Unable to get Device Interface")
            return
        }
        
        let closeResult = deviceInterface.USBDeviceClose(deviceInterfacePtrPtr)
        print("[Tyrion] closeResult = \(closeResult)")
    }
    
    //DW_TO_INT
    //#define DW_TO_INT(p) ((p)[0] | ((p)[1] << 8) | ((p)[2] << 16) | ((p)[3] << 24))
    func DWToInt(p:[UInt8]) -> UInt32 {
        return 0
    }
    
    func SWToshort(p: [UInt8]) -> UInt16 {

        if p.count < 2 {
            print("SWToshort data is error, p = \(p)")
            return 0
        }
        //[232,3] 232 + 3<<8 == 1000
        //#define SW_TO_SHORT(p) ((p)[0] | ((p)[1] << 8))
        //==> p[1] ==3, p[1]<<8 = 0。
        let result1:Int = Int(p[0])
        let result2:Int = Int(p[1])
        
        let result = ((result1)|(result2<<8))
        print("result = \(result)")
        return UInt16(result)
    }
    
    func shortToSW(s:UInt16, p :inout [UInt16]){
        if p.count < 2 {
            print("shortToSW data is error, p = \(p)")
            return
        }
        /**
         #define SHORT_TO_SW(s, p) \
           (p)[0] = (s); \
           (p)[1] = (s) >> 8;
         */
        p[0] = s
        p[1] = s >> 8
    }
}

//action event
extension CameraIOKitClass{
    
    func zoomIn() {
        
        if supportZoomRel {
            setZoomRel(x: ZOOM_IN)
        } else if supportZoomAbs {
            zoomInAbs()
        } else{
            //dont support zoom in
        }
    }
    
    func zoomOut() {
        if supportZoomRel {
            setZoomRel(x: ZOOM_OUT)
        } else if supportZoomAbs {
            zoomOutAbs()
        } else{
            //dont support zoom in
        }
    }
    
    func zoomOutAbs() {
        let target = absoluteZoomCurrent - absoluteZoomStep
        
        absoluteZoomCurrent = target
        
        if absoluteZoomCurrent < absoluteZoomMin {
            absoluteZoomCurrent = absoluteZoomMin
            //stop timer
            delegate?.stopZoomingTimer()
        }
        
        if !openDevice(){
            return
        }

        let result = setZoomAbs(bRequest: UVC_SET_CUR, focal_length: UInt16(absoluteZoomCurrent))
        print("set abs result = \(result)")

        closeDevice()
    }
    
    func zoomInAbs() {
        let target = absoluteZoomCurrent + absoluteZoomStep
        
        absoluteZoomCurrent = target
        
        if absoluteZoomCurrent > absoluteZoomMax {
            absoluteZoomCurrent = absoluteZoomMax
            //stop timer
            delegate?.stopZoomingTimer()
        }
        
        if !openDevice(){
            return
        }

        let result = setZoomAbs(bRequest: UVC_SET_CUR, focal_length: UInt16(absoluteZoomCurrent))
        print("set abs result = \(result)")
        closeDevice()
    }
}


//MARK: touch event
private extension CameraIOKitClass{
    
    //MARK: - click
    func setPantiltRel(x: Int8, y: Int8)  {
        if !openDevice(){
            closeDevice()
            return
        }

        uvc_set_pantilt_rel(pan_rel: x, panSpeed: panSpeed, tilt_rel: y, tileSpeed: tiltSpeed)
        usleep(useconds_t(CAMERA_RUNTIME * 1000));
        uvc_set_pantilt_rel(pan_rel: 0, panSpeed: panSpeed, tilt_rel: 0, tileSpeed: tiltSpeed)

        closeDevice()
    }
    
    func setZoomRel(x: Int8)  {
        if !openDevice(){
            closeDevice()
            return
        }

        uvc_set_zoom_rel(zoom: x, zoomSpeed: zoomSpeed)
        usleep(useconds_t(CAMERA_RUNTIME * 1000));
        uvc_set_zoom_rel(zoom: 0, zoomSpeed: zoomSpeed)
        
        closeDevice()
    }
    
    func setContinuousPantiltRelStart(x: Int8, y: Int8) {
        if !openDevice(){
            closeDevice()
            return
        }

        uvc_set_pantilt_rel(pan_rel: x, panSpeed: panSpeed, tilt_rel: y, tileSpeed: tiltSpeed)
        closeDevice()
    }
    
    func setContinuousPantiltRelStop() {
        if !openDevice(){
            closeDevice()
            return
        }
        uvc_set_pantilt_rel(pan_rel: 0, panSpeed: panSpeed, tilt_rel: 0, tileSpeed: tiltSpeed)
        closeDevice()
    }
    
    func setContinuousZoomRelStart(x: Int8) {
        if !openDevice(){
            closeDevice()
            return
        }

        uvc_set_zoom_rel(zoom: x, zoomSpeed: zoomSpeed)
        closeDevice()
    }
    
    func setContinuousZoomRelStop() {
        if !openDevice(){
            closeDevice()
            return
        }
        uvc_set_zoom_rel(zoom: 0, zoomSpeed: zoomSpeed)
        closeDevice()
    }
}

class CameraIOKitClass{
    
    var maxPan = 0
    var minPan = 0
    var maxTilt = 0
    var minTilt = 0
    
    var supportPan: Bool {
        if supportMoveRel {
            return panSpeed > 0
        }
        if supportMoveAbs {
            return maxPan != minPan
        }
        return false
    }
    
    var supportTilt: Bool {
        if supportMoveRel {
            return tiltSpeed > 0
        }
        if supportMoveAbs {
            return maxTilt != minTilt
        }
        return false
    }
    
    var supportZoom: Bool {
        return supportZoomAbs || supportZoomRel
    }
    
    var supportPreset: Bool {
        return supportMoveAbs && supportZoomAbs
    }
    
    var delegate: PTZControlDelegate?
    
    let kIOUSBDeviceUserClientTypeID:   CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                                0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
                                                                                0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
    
    let kIOCFPlugInInterfaceID:         CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                                0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
                                                                                0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)
    
    let kIOUSBDeviceInterfaceID:        CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                                0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xD4,
                                                                                0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
    
    var deviceInterfacePtrPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
    var plugInInterfacePtrPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
    var interfacePtrPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>?
    
    var panSpeed: UInt8 = 0
    var tiltSpeed: UInt8 = 0
    var zoomSpeed: UInt8 = 0
    
    
    var REQ_TYPE_SET:UInt8 = 0x21;
    var REQ_TYPE_GET:UInt8 = 0xa1;
    
    
    var absoluteZoomMin:Int16 = 0
    var absoluteZoomMax:Int16 = 0
    var absoluteZoomCurrent:Int16 = 0

    var absoluteZoomStep:Int16 = 0
    let CAMERA_ZOOM_STEP:UInt16 = 50
    
    var currentDevice:UInt32 = 0
    var targetDeviceID = ""
    
    var supportZoomAbs:Bool = false
    var supportZoomRel:Bool = false
    var supportMoveAbs:Bool = false
    var supportMoveRel:Bool = false
    
    
    func setCurrentVideoDevice(uniqueID:String) {
        
        targetDeviceID = uniqueID

        var result: kern_return_t = KERN_FAILURE
        var classesToMatch = IOServiceMatching(kIOUSBDeviceClassName)!
        var classesToMatchDict = (classesToMatch as NSDictionary)
            as! Dictionary<String, AnyObject>
        //classesToMatchDict[kIOSerialBSDTypeKey] = deviceType
        let classesToMatchCFDictRef = (classesToMatchDict as NSDictionary) as CFDictionary
        var serialPortIterator: io_iterator_t = 0
        result = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatchCFDictRef, &serialPortIterator);

        printSerialPaths(serialPortIterator)
    }
    
    func queryAbility() {
        var uvc_req_code:UInt8
        var res: Bool
        
        var v1:Int32 = 0
        var v2:Int32 = 0
        var v3:Int16 = 0
        var v4:UInt8 = 0
        var v5:UInt8 = 0
        var v6:UInt8 = 0
        var v7:UInt8 = 0
        var v10:UInt8 = 0
        
        if !openDevice() {
            return
        }
        uvc_req_code = UVC_GET_DEF
        res = uvc_get_zoom_abs(bRequest: uvc_req_code, focal_length: &v3)
        supportZoomAbs = res

        uvc_req_code = UVC_GET_DEF
        res = uvc_get_zoom_rel(bRequest: uvc_req_code, zoomRel: &v4, digitalZoom: &v5, zoomSpeed: &v6)
        supportZoomRel = res
        
        uvc_req_code = UVC_GET_DEF
        res = uvc_get_pantilt_abs(bRequest: uvc_req_code, pan: &v1, tilt: &v2)
        supportMoveAbs = res
        
        uvc_req_code = UVC_GET_DEF
        res = uvc_get_pantilt_rel(bRequest: uvc_req_code, panDirection: &v4, panSpeed: &v5, tiltDirection: &v10, tileSpeed: &v7)
        supportMoveRel = res
        
        print("[Tyrion] supportZoomAbs = \(supportZoomAbs), supportZoomRel = \(supportZoomRel), supportMoveAbs = \(supportMoveAbs), supportMoveRel = \(supportMoveRel)")
        closeDevice()
        
    }
    
    func didFoundCamera(_ usbDevice: io_iterator_t) {
        print("find camera")

        queryAbility()
        
        //get abs
        getZoomAbsInfos()

        
        print("[Tyrion] absoluteZoomMin = \(absoluteZoomMin), absoluteZoomMax = \(absoluteZoomMax), absoluteZoomCurrent = \(absoluteZoomCurrent), absoluteZoomStep = \(absoluteZoomStep)")
        
        //get rel
        getSupportPanTiltRel()
        
        print("[Tyrion] getSupportPanTiltRel, device = \(currentDevice.description),result = \(String(describing: getSupportPanTiltRel())), panSpeed = \(panSpeed),tiltSpeed = \(tiltSpeed) ")
        
        closeDevice()
        
    }
    
    func getSupportPanTiltRel() {
        
        if !openDevice() {
            return
        }
        
        var panDirection:UInt8 = 0
        var tiltDirection:UInt8 = 0
        
        
       let result = uvc_get_pantilt_rel(bRequest: UVC_GET_DEF, panDirection: &panDirection, panSpeed: &panSpeed, tiltDirection: &tiltDirection, tileSpeed: &tiltSpeed)
        
        
        if (result != false) {
            panDirection = 1;
            tiltDirection = 1;
        }
        
        closeDevice()
        
    }
    
    func getZoomAbsInfos() {

        if !openDevice() {
            return
        }
        
        uvc_get_zoom_abs(bRequest: UVC_GET_MIN, focal_length: &absoluteZoomMin)
        uvc_get_zoom_abs(bRequest: UVC_GET_MAX, focal_length: &absoluteZoomMax)
        uvc_get_zoom_abs(bRequest: UVC_GET_CUR, focal_length: &absoluteZoomCurrent)

        absoluteZoomStep = (absoluteZoomMax - absoluteZoomMin)/Int16(CAMERA_ZOOM_STEP);
        
        print("absoluteZoomMin = \(absoluteZoomMin), absoluteZoomMax = \(absoluteZoomMax), absoluteZoomCurrent = \(absoluteZoomCurrent), absoluteZoomStep = \(absoluteZoomStep)")
        
        //close device
        closeDevice()
    }
    
    func USBmakebmRequestType(direction:Int, type:Int, recipient:Int) -> UInt8 {
        return UInt8((direction & kUSBRqDirnMask) << kUSBRqDirnShift)|UInt8((type & kUSBRqTypeMask) << kUSBRqTypeShift)|UInt8(recipient & kUSBRqRecipientMask)
    }
    
    func setZoomAbs(bRequest:UInt8, focal_length: UInt16) -> Bool{
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 2
        
        var requestPtr:[UInt16] = [UInt16](repeating: 0, count: length)
        
        print("focal_length = \(focal_length)")
        shortToSW(s: focal_length, p: &requestPtr)
        
        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_SET,
                                   bRequest: bRequest,
                                   wValue: UVC_CT_ZOOM_ABSOLUTE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
 
        }
        if request.wLength == length {
            return true
        }
        return false
    }

    let CAMERA_RUNTIME = 200

    
    func printSerialPaths(_ iterator: io_iterator_t) {
        while case let usbDevice = IOIteratorNext(iterator), usbDevice != 0 {
            
            //get pid,vid,locationID. ==> startWithCameraID
            let pid = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"idProduct" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents)) as! NSNumber).uint32Value
            let vid = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"idVendor" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents))  as! NSNumber).uint32Value
            let locationID = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"locationID" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents)) as! NSNumber).uint32Value
            var name: [CChar] = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(usbDevice, &name);
            
            let targetID = String(format: "0x%x%.4x%.4x", locationID,vid,pid)
            
            if targetDeviceID == targetID {
                currentDevice = usbDevice
                //print("targetID = \(targetID), usbDevice= \(usbDevice)")
                didFoundCamera(usbDevice)
                return
            }
        }
    }
}

// UVC
extension CameraIOKitClass {
 
    @discardableResult func uvc_set_zoom_rel(zoom:Int8, zoomSpeed:UInt8) -> Bool {
        
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 3
        
        var requestPtr:[Int8] = [Int8](repeating: 0, count: length)
        
        /**
         data[0] = zoom_rel;
         data[1] = digital_zoom;
         data[2] = speed;
         */
        
        //TODO
        let digital_zoom:Int8 = 0
        
        requestPtr[0] = zoom
        requestPtr[1] = digital_zoom
        requestPtr[2] = Int8(zoomSpeed)

        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_SET,
                                   bRequest: UVC_SET_CUR,
                                   wValue: UVC_CT_ZOOM_RELATIVE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
 
        }
        if request.wLength == length {
            return true
        }
        return false
      }
    
    @discardableResult func uvc_set_pantilt_rel(pan_rel:Int8, panSpeed:UInt8, tilt_rel:Int8, tileSpeed:UInt8) -> Bool {
        
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 4
        
        var requestPtr:[Int8] = [Int8](repeating: 0, count: length)
        requestPtr[0] = pan_rel
        requestPtr[1] = Int8(panSpeed)
        requestPtr[2] = tilt_rel
        requestPtr[3] = Int8(tileSpeed)

        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_SET,
                                   bRequest: UVC_SET_CUR,
                                   wValue: UVC_CT_PANTILT_RELATIVE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
 
        }
        if request.wLength == length {
            return true
        }
        return false
      }
    
    func uvc_get_pantilt_abs(bRequest:UInt8, pan :inout Int32, tilt :inout Int32) -> Bool{
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 2
        
        var requestPtr:[UInt8] = [UInt8](repeating: 0, count: length)
        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_GET,
                                   bRequest: bRequest,
                                   wValue: UVC_CT_PANTILT_ABSOLUTE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
            return false
        }
        if request.wLength == length {
//            focal_length = Int16(SWToshort(p: requestPtr))
            //pan = DWToInt(p: <#T##[UInt8]#>)
            return true
        }
        return false
    }
    
    func uvc_get_pantilt_rel(bRequest:UInt8, panDirection :inout UInt8, panSpeed :inout UInt8, tiltDirection :inout UInt8, tileSpeed: inout UInt8) -> Bool{
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 4
        
        
        var requestPtr:[UInt8] = [UInt8](repeating: 0, count: length)
        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_GET,
                                   bRequest: bRequest,
                                   wValue: UVC_CT_PANTILT_RELATIVE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
 
        }
        if request.wLength == length {
            panDirection = requestPtr[0]
            panSpeed = requestPtr[1]
            tiltDirection = requestPtr[2]
            tileSpeed = requestPtr[3]
            return true
        }
        return false
    }

    
    func uvc_get_zoom_rel(bRequest:UInt8, zoomRel :inout UInt8, digitalZoom :inout UInt8, zoomSpeed :inout UInt8) -> Bool{
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 3
        
        
        var requestPtr:[UInt8] = [UInt8](repeating: 0, count: length)
        var request = requestPtr.withUnsafeMutableBufferPointer { p in

            return IOUSBDevRequest(bmRequestType: REQ_TYPE_GET,
                                   bRequest: bRequest,
                                   wValue: UVC_CT_ZOOM_RELATIVE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
            return false
        }
        if request.wLength == length {
            zoomRel = requestPtr[0]
            digitalZoom = requestPtr[1]
            zoomSpeed = requestPtr[2]
            return true
        }else{
            return false
        }
    }
    
    @discardableResult
    func uvc_get_zoom_abs(bRequest:UInt8, focal_length:inout Int16) -> Bool{
        guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            return false
        }
        
        var kr:Int32 = 0
        let length:Int = 2
        
        var requestPtr:[UInt8] = [UInt8](repeating: 0, count: length)
        var request = requestPtr.withUnsafeMutableBufferPointer { p in
            
            return IOUSBDevRequest(bmRequestType: REQ_TYPE_GET,
                                   bRequest: bRequest,
                                   wValue: UVC_CT_ZOOM_ABSOLUTE_CONTROL << 8,
                                   wIndex: 256,
                                   wLength: UInt16(length),
                                   pData: p.baseAddress!,
                                   wLenDone: 255)
        }
        
        kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)
        
        if (kr != kIOReturnSuccess) {
            print("Get device status request error: \(kr)")
            return false
        }
        print("result, requestPtr = \(requestPtr), request.wLenDone = \(request.wLenDone)")
        if request.wLenDone != length {
            print("no supported zoom abs")
            return false
        }
        if request.wLength == length {
            focal_length = Int16(SWToshort(p: requestPtr))
            return true
        }
        return false
    }
}
