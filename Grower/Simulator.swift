//
//  Simulator.swift
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Foundation
import SwiftCL
import OpenCL

class Simulator {
  
  let queue: CommandQueue!
  let renderKernel: Kernel!
  let positions: Buffer<Float>!
  let pixels: Buffer<Float>!
  let width: cl_int
  let height: cl_int
  
  init?(width:Int, height:Int) {
    self.width = cl_int(width)
    self.height = cl_int(height)
    
    if let context = Context(fromType: CL_DEVICE_TYPE_GPU, properties: nil, errorHandler: errorHandler("Context")) {
      if let queue = CommandQueue(context: context, device: nil, properties: 0, errorHandler: errorHandler("CommandQueue")) {
        self.queue = queue
        
        if let program = Program(
          context: context,
          loadFromMainBundle: "render.cl",
          compilationType: .CompileAndLink,
          errorHandler: errorHandler("Program")) {
            if let kernel = Kernel(program: program, name: "render", errorHandler: errorHandler("Kernel")) {
              self.renderKernel = kernel
            }
        }
        
        if let buffer = Buffer<cl_float>(context: context, count: Int(width * height), readOnly: false, errorHandler: errorHandler("Pixels buffer")) {
          pixels = buffer
        }
        
        if let buffer = Buffer<cl_float>(context: context, count: 4 * 4, readOnly: true, errorHandler: errorHandler("Positions buffer")) {
          positions = buffer
        }
        
        if (renderKernel != nil && positions != nil && pixels != nil) {
          return
        }
      }
    }
    return nil
  }
  
  func step() -> Bool {
    if let kernel = renderKernel.setArgs(width, height, pixels, positions, errorHandler: errorHandler("Prepare kernel")) {
      let result = queue.enqueue(kernel, globalWorkSize: [UInt(width), UInt(height)])
      if result != CL_SUCCESS {
        return false
      }
    }
    return queue.enqueueRead(positions) == CL_SUCCESS
  }
  
  func errorHandler(label:String)(param:Int32, result:cl_int) {
    println("\(label) error for param \(param): \(result)")
  }
  func errorHandler(label:String)(param:Int32, result:cl_int) {
    println("\(label) error for param \(param): \(result)")
  }
  func errorHandler(label:String)(result:cl_int) {
    println("\(label) error: \(result)")
  }
  func errorHandler(label:String)(result: cl_int, desc: String) {
    println("\(label) error: \(result): \(desc)")
  }
}