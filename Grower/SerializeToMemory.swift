//
//  Array+SerializableToMemory.swift
//  Grower
//
//  Created by Lukasz Kwoska on 19/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation
import OpenCL
import SwiftCL

func serializeToMemory<T:MemorySerializable>(array:[T], context: Context, flags: Int32, errorHandler: ((cl_int) -> Void)? = nil) -> SwiftCL.Memory? {
  let size = T.size() * array.count
  let ptr = UnsafeMutablePointer<Void>.alloc(size)
  var writePtr = ptr
  for object in array {
    object.serialize(writePtr)
    writePtr = writePtr.advancedBy(T.size())
  }
  
  return SwiftCL.Memory(context: context, flags: flags, size: UInt(size), hostPtr: ptr, errorHandler: errorHandler)
}

func serializeToPtr<T>(ptr: UnsafeMutablePointer<Void>, value: T) -> UnsafeMutablePointer<Void> {
  UnsafeMutablePointer<T>(ptr).memory = value
  return ptr.advancedBy(sizeof(T))
}