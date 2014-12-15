//
//  PackedStruct.swift
//  Grower
//
//  Created by Lukasz Kwoska on 12/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

class PackedStruct {
  let ptr: UnsafeMutablePointer<Void>
  init(ptr:UnsafeMutablePointer<Void>) {
    self.ptr = ptr
  }
  
  func storeFloat(value: Float, offset: Int) {
    UnsafeMutablePointer<Float>(ptr.advancedBy(offset)).memory = value
  }
  
  func loadFloat(offset: Int) -> Float {
    return UnsafeMutablePointer<Float>(ptr.advancedBy(offset)).memory
  }
  
  func storeInt32(value: Int32, offset: Int) {
    UnsafeMutablePointer<Int32>(ptr.advancedBy(offset)).memory = value
  }
  
  func loadInt32(offset: Int) -> Int32 {
    return UnsafeMutablePointer<Int32>(ptr.advancedBy(offset)).memory
  }
  
  class func size() -> Int {
    return 0
  }
}
