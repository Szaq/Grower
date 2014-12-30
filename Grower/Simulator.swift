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

func time2str(time:CFTimeInterval) -> String {
  let hours = Int(time) / 3600
  let minutes = (Int(time) / 60) % 60
  let seconds = Int(time) % 60
  
  return [(hours, "h"), (minutes, "m"), (seconds, "s")].reduce("", combine: { previous, current in
    current.0 > 0 ? "\(previous)\(current.0)\(current.1)" : previous
  })

}

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
  let simulationStatTime: CFTimeInterval
  
  var statsHandler:((String)->Void)?
  
  init?(width:Int, height:Int) {
    self.width = cl_int(width)
    self.height = cl_int(height)
    self.simulationStatTime = CACurrentMediaTime()
    
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
                        let buildInfo = program.getBuildInfo(context.getInfo().deviceIDs[0])
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
                0, 0, -1000001, 1000000,
                1000020, 0, 0, 1000000,
                0, 0, 1000040, 1000000,
                0,1,30,3,
                0,-6,30,4,
                10,-2,30,5,
                -1,-4,20,4,
                0, 1000015, 0, 1000000,
                0,12,30,2,
              ],
              readOnly: true,
              errorHandler: errorHandler("Positions buffer")) {
                positions = buffer
            }

            if let materials = serializeToMemory([
              Material(color: (0.75, 0, 0, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0.75, 0.75, 0.75, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0.75, 0.75, 0.75, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0, 0.75, 0, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0.75, 0.75, 0.75, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0, 0.5, 0.75, 1), type: .Diffuse, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (0.75, 0.75, 0.75, 1), type: .Diffuse, IOR: 0.1, roughness:0.3, dummy: 0),
              Material(color: (1.0, 1.0, 1.0, 1), type: .Glossy, IOR: 10, roughness:0.1, dummy: 0),
              Material(color: (1, 0.75, 0.2, 1), type: .Transparent, IOR: 1.5, roughness:0, dummy: 0),
              Material(color: (0.75, 0.75, 0.75, 1), type: .Emitter, IOR: 1.2, roughness:0, dummy: 0),
              Material(color: (1, 1, 1, 1), type: .Diffuse, IOR: 0.0, roughness:0, dummy: 0)
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
            for i in 0..<10 {
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
    samples += 10
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
      let time = time2str(CACurrentMediaTime() - self.simulationStatTime)
      let stats = "[\(time)]\t \(msamplesPerSec) MS/sec\t\(samplesPerPixel) S/px"
      println(stats)
      if let statsHandler = self.statsHandler {
        statsHandler(stats)
      }
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