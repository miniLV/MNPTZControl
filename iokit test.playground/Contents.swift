import Foundation
import IOKit
import IOKit.usb
import IOKit.serial
import AVFoundation

let kIOUSBDeviceUserClientTypeID:   CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                            0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
                                                                            0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

let kIOCFPlugInInterfaceID:         CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                            0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
                                                                            0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)

let kIOUSBDeviceInterfaceID:        CFUUID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
                                                                            0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xD4,
                                                                            0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

let devices = AVCaptureDevice.devices(for: .video)
print("devices = \(devices)")
let target = devices.first?.uniqueID ?? ""
print(target)

var deviceInterfacePtrPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
var plugInInterfacePtrPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
var interfacePtrPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>?

func didFoundCamera(_ usbDevice: io_iterator_t) {
    print("find")
    var configPtr:IOUSBConfigurationDescriptorPtr?
    var score:Int32 = 0
    var kr:Int32 = 0
    
    let plugInInterfaceResult = IOCreatePlugInInterfaceForService(
        usbDevice,
        kIOUSBDeviceUserClientTypeID,
        kIOCFPlugInInterfaceID,
        &plugInInterfacePtrPtr,
        &score)
    guard plugInInterfaceResult == kIOReturnSuccess,
        let plugInInterface = plugInInterfacePtrPtr?.pointee?.pointee else {
            print("Unable to get Plug-In Interface")
            return
    }
    
    let deviceInterfaceResult = withUnsafeMutablePointer(to: &deviceInterfacePtrPtr) {
        $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) {
            plugInInterface.QueryInterface(
                plugInInterfacePtrPtr,
                CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                $0)
        }
    }
    
    guard deviceInterfaceResult == kIOReturnSuccess,
        let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
            print("Unable to get Device Interface")
            return
    }
    
    var ret = deviceInterface.USBDeviceOpen(deviceInterfacePtrPtr)
    guard (ret == kIOReturnSuccess) else {
        print("open fail")
        return
    }
    ret = deviceInterface.GetConfigurationDescriptorPtr(deviceInterfacePtrPtr, 0, &configPtr)
    guard let config = configPtr?.pointee else {
        print("get config ptr fail")
        return
    }
    guard config.bLength > 0 else {return}
    print(getStatus(bRequest: 0x87))
}

func USBmakebmRequestType(direction:Int, type:Int, recipient:Int) -> UInt8 {
    return UInt8((direction & kUSBRqDirnMask) << kUSBRqDirnShift)|UInt8((type & kUSBRqTypeMask) << kUSBRqTypeShift)|UInt8(recipient & kUSBRqRecipientMask)
}

func getStatus(bRequest:UInt8) -> [UInt8]? {
    guard let deviceInterface = deviceInterfacePtrPtr?.pointee?.pointee else {
        return nil
    }

    var kr:Int32 = 0
    let length:Int = 2
    var requestPtr:[UInt8] = [UInt8](repeating: 0, count: length)
    var request = requestPtr.withUnsafeMutableBufferPointer { p in
        return IOUSBDevRequest(bmRequestType: 0xa1,
        bRequest: bRequest,
        wValue: 0x0b << 8,
        wIndex: 256,
        wLength: UInt16(length),
        pData: p.baseAddress!,
        wLenDone: 255)
    }
    
    kr = deviceInterface.DeviceRequest(deviceInterfacePtrPtr, &request)

    if (kr != kIOReturnSuccess) {
        print("Get device status request error: \(kr)")
        return nil
    }
    print(requestPtr,request.wLenDone)
    if request.wLenDone != length {
        print("no supported zoom abs")
    }
    return requestPtr
}


func printSerialPaths(_ iterator: io_iterator_t) {
    while case let usbDevice = IOIteratorNext(iterator), usbDevice != 0 {
        let pid = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"idProduct" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents)) as! NSNumber).uint32Value
        let vid = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"idVendor" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents))  as! NSNumber).uint32Value
        let locationID = (IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane,"locationID" as CFString,kCFAllocatorDefault,IOOptionBits(kIORegistryIterateRecursively|kIORegistryIterateParents)) as! NSNumber).uint32Value
        var name: [CChar] = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(usbDevice, &name);
        let targetID = String(format: "0x%x%.4x%.4x", locationID,vid,pid)
        if target == targetID {
            didFoundCamera(usbDevice)
            return
        }
    }
}

var result: kern_return_t = KERN_FAILURE
var classesToMatch = IOServiceMatching(kIOUSBDeviceClassName)!
var classesToMatchDict = (classesToMatch as NSDictionary)
    as! Dictionary<String, AnyObject>
//classesToMatchDict[kIOSerialBSDTypeKey] = deviceType
let classesToMatchCFDictRef = (classesToMatchDict as NSDictionary) as CFDictionary
var serialPortIterator: io_iterator_t = 0
result = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatchCFDictRef, &serialPortIterator);

printSerialPaths(serialPortIterator)
