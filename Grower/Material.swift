//
//  Material.swift
//  Grower
//
//  Created by Lukasz Kwoska on 19/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation

typealias Color4F = (Float, Float, Float, Float)

enum ShaderType : Int32 {
  case Diffuse = 0
  case Emitter
  case Glossy
}

struct Material :MemorySerializable {
  
  let color: Color4F
  let type: ShaderType
  let IOR: Float
  let roughness: Float
  let dummy: Float
  
  func serialize(ptr: UnsafeMutablePointer<Void>) {
    serializeToPtr(
      serializeToPtr(
        serializeToPtr(
          serializeToPtr(
            serializeToPtr(
              serializeToPtr(
                serializeToPtr(ptr, color.0),
                color.1),
              color.2),
            color.3),
          type.rawValue),
        IOR),
      roughness)
  }
  
  static func size() -> Int {
    return 32
  }
}