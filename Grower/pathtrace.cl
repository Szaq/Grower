//
//  render.cl
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

#include "prng.cl"

typedef struct {
  float3 origin;
  float padding1;
  //Normalized direction vector
  float3 dir;
  float padding2;
} ray;

float intersectSphere(ray r, float4 s);
float nearestIntersection(ray r, int sphere_count, __global float4 *spheres, int *objID);
ray reflectRay(ray r, float3 point, float3 normal);


float intersectSphere(ray r, float4 s) {
  
  float3 centerToOriginVec = r.origin - s.xyz;
  
  float dottedDirs = dot(r.dir, centerToOriginVec);
  
  float delta = dottedDirs * dottedDirs + s.w * s.w - dot(centerToOriginVec, centerToOriginVec);
  
  if (delta < 0) {
    return -1;
  }
  
  if (delta == 0) {
    return -dottedDirs;
  }
  
  delta = sqrt(delta);
  
  float d1 = -dottedDirs - delta;
  float d2 = -dottedDirs + delta;
  
  //Warning - Case when we're inside sphere is not correctly  handled
  if (d2 < d1) {
    d1 = d2;
  }
  
  return d1;
}

float nearestIntersection(ray r, int sphere_count, __global float4 *spheres, int *objID) {
  float minT = FLT_MAX;
  for (int id = 0; id < sphere_count; id++) {
    float t = intersectSphere(r, spheres[id]);
    if (t > 0.0f && t < minT && id != *objID) {
      minT = t;
      *objID = id;
    }
  }
  
  return (minT < FLT_MAX) ? minT : -1.0f;
}

ray reflectRay(ray r, float3 point, float3 normal) {
  ray reflectedRay;
  reflectedRay.origin = point;
  reflectedRay.dir = normalize(r.dir - 2 * normal * dot(r.dir, normal));
  return reflectedRay;
}


ray eyeRay(int x, int y, int width, int height, PRNG *randomState) {
  float fovX = 3.14f / 6;
  float fovY = height * fovX / width;
  
  ray r;
  r.origin = (float3)(0, 0, 0);
  r.dir = normalize((float3)((2 * (x + rand(randomState) - 0.5f) - width)  * tan(fovX) / width ,
                             (2 * (y + rand(randomState) - 0.5f) - height) * tan(fovY) / height ,
                             1));
  return r;
}



//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, int seed, __global float4 *outputBuffer,
                     int sphere_count, __global float4 *spheres) {
  
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  //Initialize PRG
  PRNG randomState = init(y * width + x, seed);
//  MWC64XVEC4_SeedStreams(&rand, y * width + height, 1);
  
  //Generate eye ray
  ray r = eyeRay(x, y, width, height, &randomState);
  
  //Find nearest eye-ray intersection
  int objID = -1;
  float t = nearestIntersection(r, sphere_count, spheres, &objID);
  
  float3 color = (float3)(1);
  
  if (t >= 0) {
    
    //Check if anything is blocking the light
    float mul = 1.0f;
    
    for (int i = 0; i < 3; i++) {
      //End criteria
      if (i == 2) {
        mul = 0;
        break;
      }
      float3 sphereCenter = spheres[objID].xyz;
      float3 hitPoint = r.origin + r.dir * t;
      float3 sphereNormal = normalize(hitPoint - sphereCenter);
      
      
      //Generate randomly reflected ray
      r.origin = hitPoint;
      r.dir = normalize((float3)(rand(&randomState) - 0.5f, rand(&randomState) - 0.5f, rand(&randomState) - 0.5f));
      
      if (dot(r.dir, sphereNormal) < 0) {
        r.dir = - r.dir;
      }
      
      //Find reflected ray's nearest intersection
      t = nearestIntersection(r, sphere_count, spheres, &objID);
      if (t > 0) {
        if (objID == (sphere_count - 1)) {
          //Reflected ray hit light
          break;
        }
        
        //Indirect lighting
        mul *= dot(r.dir, sphereNormal) * 0.4f;
        //compute color (assume white light)

      }
      else {
        //Reflected ray hit nothing
        mul = 0;
        break;
      }
    }
    
    color *= mul;
  }
  else {
    color = (float3)(0);
  }
  
  outputBuffer[(height - y - 1) * width + x] += (float4)(color, 1);
   
}

__kernel void tonemap(int width, int height, int samplesCount, __global uchar4 *pixels, __global float4 *buffer) {
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  int offset = y * width + x;
  //Linear tonemapping
  float4 color = min(buffer[offset] * 255 * 10 / samplesCount, (float4)(255));
  pixels[offset] = (uchar4)(color.x, color.y, color.z, 255);
}