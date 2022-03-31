//
//  PtzQueueFactory.swift
//  IOKitDemo
//
//  Created by Tyrion Liang 1 on 2021/3/3.
//

import Cocoa


class PtzQueueFactory: NSObject {
    
    static let getOperationQueue = DispatchQueue(label: "com.singletioninternal.queue")
                                   
}
