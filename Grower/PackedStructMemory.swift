//
//  PackedStructMemory.swift
//  Grower
//
//  Created by Lukasz Kwoska on 12/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

class PackedStructMemory<T : PackedStruct> {
  let ptr: UnsafeMutablePointer<Void>
  let size: Int
  
  init(ptr: UnsafeMutablePointer<Void>, size: Int) {
    self.size = size
    self.ptr = ptr
  }
  
  subscript (idx: Int) -> T {
    let type = T.self
    let offset = type.size() * idx
    assert(offset < size)
    let resp = type(ptr: ptr.advancedBy(offset))
    return resp
  }

}
