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
  let materials: Memory!
  let outputBuffer: Buffer<Float>!
  let pixels: Buffer<UInt8>!
  let width: cl_int
  let height: cl_int
  var samples: cl_int = 0
  var samplesInLastReport: cl_int = 0
  
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
            
            let headers = ["prng.cl", "intersections.h", "shading.h", "common.h", "ray.h"];
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
                  options: nil,
                  headers: headerPrograms,
                  errorHandler: errorHandler("Compile")) {
                    let buildInfo = program.getBuildInfo(context.getInfo().deviceIDs[0])
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
                -1000020, 0, 0, 1000000,
                0, -1000010, 0, 1000000,
               // 0, 0, -1001000, 1000000,
                1000020, 0, 0, 1000000,
                0, 0, 1000060, 1000000,
                0,10,40,5,
                0,-5,40,5,
                10,0,40,5,
                -10,0,40,5,
                0, 1000150, 0, 1000000,
                0,100,20,50,
              ],
              readOnly: true,
              errorHandler: errorHandler("Positions buffer")) {
                positions = buffer
            }

            if let materials = serializeToMemory([
              Material(color: (1, 0, 0, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (1, 0, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (0, 1, 0, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (0, 0, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (0, 1, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (1, 1, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (0, 0.5, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (1, 0.5, 0, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (0.5, 0, 1, 1), type: .Diffuse, IOR: 1.2, dummy: (0,0)),
              Material(color: (1, 1, 1, 1), type: .Emitter, IOR: 0.0, dummy: (0,0))
              ],
              context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR, errorHandler: errorHandler("Materials buffer")) {
              self.materials = materials
            }
            
            if (renderKernel != nil && positions != nil && pixels != nil && outputBuffer != nil && materials != nil) {
              return
            }
        }
    }
    return nil
  }
  
  func step() -> Bool {
            for i in 0..<100 {
              let randSeed = samples + i
              if let kernel = renderKernel.setArgs(width, height, randSeed, outputBuffer, cl_int(positions.objects.count / 4), positions, materials,
                errorHandler: errorHandler("Prepare kernel")) {
                  let result = queue.enqueue(kernel, globalWorkSize: [UInt(width), UInt(height)])
                  if result != CL_SUCCESS {
                    errorHandler("Kernel enqueue")(result: result)
                    return false
                  }
              }
    }
    samples += 100
    return true
  }
  
  func currentImage() -> NSImage? {
    let samplesCount = max(samples, 1)
    if let kernel = tonemapKernel.setArgs(width, height, samplesCount, pixels, outputBuffer,
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
  
  func reportStats() {
    let timeStart = CACurrentMediaTime()
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1000000000), dispatch_get_main_queue()) {
      let timePassed = CACurrentMediaTime() - timeStart;
      let samplesSinceLastReport = self.samples - self.samplesInLastReport
      self.samplesInLastReport = self.samples
      let msamplesPerSec = Float(samplesSinceLastReport * self.width * self.height) / Float(timePassed * 1000000)
      let samplesPerPixel = Float(self.samples)
      println("\(msamplesPerSec) MS/sec\t\(samplesPerPixel) S/px")
      
      self.reportStats();
    }
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