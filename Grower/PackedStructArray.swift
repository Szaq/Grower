//
//  PackedStructArray.swift
//  Grower
//
//  Created by Lukasz Kwoska on 12/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

class PackedStructArray<T : PackedStruct> {
  private(set) var data: [Float]
  let count: Int
  
  init(count: Int) {
    self.count = count
    self.data = [Float](count: count * T.size() / sizeof(Float), repeatedValue:0)
  }
  
  subscript (idx: Int) -> T {
    let type = T.self


    assert(idx < count)
    
    let offset = type.size() * idx
    let resp = type(ptr: ptr(&data).advancedBy(offset))
    return resp
  }
  
  private func ptr(ptr:UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void> {
    return ptr
  }
  
}
