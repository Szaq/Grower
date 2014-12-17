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
  let tonemapKernel: Kernel!
  let positions: Buffer<Float>!
  let outputBuffer: Buffer<Float>!
  let pixels: Buffer<UInt8>!
  let width: cl_int
  let height: cl_int
  
  init?(width:Int, height:Int) {
    self.width = cl_int(width)
    self.height = cl_int(height)
    
    if let context = Context(
      fromType: CL_DEVICE_TYPE_GPU,
      properties: nil,
      errorHandler: errorHandler("Context")) {
        if let queue = CommandQueue(
          context: context,
          device: nil,
          properties: 0,
          errorHandler: errorHandler("CommandQueue")) {
            self.queue = queue
            
            let headers = ["mwc64x_rng.cl", "mwc64xvec2_rng.cl", "mwc64xvec4_rng.cl", "mwc64xvec8_rng.cl", "skip_mwc.cl"]
            let headerPrograms = toDictionary(headers) { name -> (String, Program)? in
                if let program = Program(
                context: context,
                loadFromMainBundle: name,
                compilationType: .None,
                  errorHandler: self.errorHandler("Header load")) {
                    return (name, program)
                }
                return nil
            }
              
            
            
            if let program = Program(
              context: context,
              loadFromMainBundle: "pathtrace.cl",
              compilationType: .None,
              errorHandler: errorHandler("Program")) {
                if program.compile(
                  devices: nil,
                  options: "-cl-opt-disable",
                  headers: headerPrograms,
                  errorHandler: errorHandler("Compile")) {
                    if let program = linkPrograms(context, [program],
                      options: nil,
                      devices: nil,
                      errorHandler: errorHandler("Link")) {
                      if let kernel = Kernel(program: program, name: "render", errorHandler: errorHandler("Kernel")) {
                        self.renderKernel = kernel
                      }
                      
                      if let kernel = Kernel(program: program, name: "tonemap", errorHandler: errorHandler("Kernel")) {
                        self.tonemapKernel = kernel
                      }
                    }
                }
            }
            
            if let buffer = Buffer<UInt8>(
              context: context,
              count: Int(width * height * 4),
              readOnly: false,
              errorHandler: errorHandler("Pixels buffer")) {
                pixels = buffer
            }
            
            if let buffer = Buffer<Float>(
              context: context,
              copyFrom: [cl_float](count:Int(width * height * 4), repeatedValue:0.0),
              readOnly: false,
              errorHandler: errorHandler("Output buffer")) {
                outputBuffer = buffer
            }
            
            if let buffer = Buffer<Float>(
              context: context,
              copyFrom:
              [
                -50, 10, 200, 20,
                0, -1000010, 0, 1000000,
                100, 40, 300, 50,
                50, 200, 20, 50,
              ],
              readOnly: true,
              errorHandler: errorHandler("Positions buffer")) {
                positions = buffer
            }
            
            if (renderKernel != nil && positions != nil && pixels != nil && outputBuffer != nil) {
              return
            }
        }
    }
    return nil
  }
  
  func step() -> Bool {
    if let kernel = renderKernel.setArgs(width, height, outputBuffer, cl_int(positions.objects.count / 4), positions,
      errorHandler: errorHandler("Prepare kernel")) {
        for i in 0..<100 {
          let result = queue.enqueue(kernel, globalWorkSize: [UInt(width), UInt(height)])
          if result != CL_SUCCESS {
            return false
          }
        }
    }
    return queue.enqueueRead(pixels) == CL_SUCCESS
  }
  
  func currentImage() -> NSImage? {
    if let kernel = tonemapKernel.setArgs(width, height, 100, pixels, outputBuffer,
      errorHandler: errorHandler("Tonemap")) {
      if queue.enqueue(kernel, globalWorkSize: [UInt(width), UInt(height)]) != CL_SUCCESS {
        return nil
      }
      
      if queue.enqueueRead(pixels) != CL_SUCCESS {
        return nil
      }
    }
    
    if let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(width),
      pixelsHigh: Int(height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: NSDeviceRGBColorSpace,
      bitmapFormat: NSBitmapFormat.NSAlphaNonpremultipliedBitmapFormat,
      bytesPerRow:Int(4 * width),
      bitsPerPixel: 32) {
        
        memcpy(bitmap.bitmapData, pixels.data, UInt(width * height * 4));
        let image = NSImage()
        image.addRepresentation(bitmap)
        return image
    }
    
    return nil
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