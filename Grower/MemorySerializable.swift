//
//  MemorySerializable.swift
//  Grower
//
//  Created by Lukasz Kwoska on 19/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

protocol MemorySerializable {
  func serialize(ptr: UnsafeMutablePointer<Void>)
  class func size() -> Int
}