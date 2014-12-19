//
//  render.cl
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

#include "prng.cl"

#include "common.h"
#include "ray.h"
#include "intersections.h"
#include "shading.h"


//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, int seed, __global float4 *outputBuffer,
                     int objectCount, OBJECT_GEOMETRIES objects,
                     OBJECT_MATERIALS materials) {
  
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  //Initialize PRG
  PRNG randomState = init(y * width + x, seed);
//  MWC64XVEC4_SeedStreams(&rand, y * width + height, 1);
  
  //Generate eye ray
  ray r = eyeRay(x, y, width, height, &randomState);
  
  //Find nearest eye-ray intersection
  int objID = -1;
  float t = nearestIntersection(r, objectCount, objects, &objID);
  
  float4 color = (float4)(1);
  
  if (t >= 0) {
    
    for (int i = 0; i < 3; i++) {
      //End criteria
      if (i == 2) {
        color = (float4)(0, 0, 0, 1);
        break;
      }
      
      
      float3 sphereCenter = objects[objID].xyz;
      float3 hitPoint = r.origin + r.dir * t;
      float3 localPoint = hitPoint - sphereCenter;
      float3 sphereNormal = normalize(localPoint);
      
      color *= surfaceColor(materials[objID], localPoint, r.dir);
      
      //Generate randomly reflected ray
      r = randomRayInHemisphere(hitPoint, sphereNormal, &randomState);
      
      //Find reflected ray's nearest intersection
      t = nearestIntersection(r, objectCount, objects, &objID);
      if (t > 0) {
        
        if (surfaceIsEmitter(materials[objID])) {
          //Reflected ray hit light
          break;
        }
        
        //Indirect lighting
        color.xyz *= (float3)dot(r.dir, sphereNormal);
      }
      else {
        //Reflected ray hit nothing
        color = (float4)(0, 0, 0, 1);
        break;
      }
    }
  }
  else {
    color = (float4)(0, 0, 0, 1);
  }
  
  outputBuffer[(height - y - 1) * width + x] += (float4)(color.xyz, 1);
   
}

__kernel void tonemap(int width, int height, int samplesCount, __global uchar4 *pixels, __global float4 *buffer) {
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  int offset = y * width + x;
  //Linear tonemapping
  float4 color = min(buffer[offset] * 255 * 10 / samplesCount, (float4)(255));
  pixels[offset] = (uchar4)(color.x, color.y, color.z, 255);
}