//
//  Float3.swift
//  Grower
//
//  Created by Lukasz Kwoska on 12/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

class Float3 : PackedStruct {
  
  var x: Float {
    get {return loadFloat(0)}
    set {storeFloat(newValue, offset: 0)}
  }
  
  var y: Float {
    get {return loadFloat(4)}
    set {storeFloat(newValue, offset: 4)}
  }
  
  var z: Float {
    get {return loadFloat(8)}
    set {storeFloat(newValue, offset: 8)}
  }
  
  override class func size() -> Int {
    return 12
  }
  
}