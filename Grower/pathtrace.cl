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
  
  if (d2 < d1 || d1 < 0) {
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


//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, int seed, __global float4 *outputBuffer,
                     int sphere_count, __global float4 *spheres) {
  
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  //Initialize PRG
  PRNG randomState = init(y * width + x, seed);
//  MWC64XVEC4_SeedStreams(&rand, y * width + height, 1);
  
  //Generate eye ray
  float fovX = 3.14f / 6;
  float fovY = height * fovX / width;
  
  ray r;
  r.origin = (float3)(0, 0, 0);
  r.dir = normalize((float3)((2 * x - width)  * tan(fovX) / width ,
                             (2 * y - height) * tan(fovY) / height ,
                             1));
  
  
  //Find nearest eye-ray intersection
  int objID = -1;
  float t = nearestIntersection(r, sphere_count, spheres, &objID);
  
  float3 color = (float3)(1);
  
  if (t >= 0) {
    
    //Check if anything is blocking the light
    float mul = 1.0f;
    
    ray reflectedRay = r;
    int dummyID = objID;
    
    for (int i = 0; i < 6; i++) {
      float3 sphereCenter = spheres[dummyID].xyz;
      float3 hitPoint = reflectedRay.origin + reflectedRay.dir * t;
      float3 sphereNormal = normalize(hitPoint - sphereCenter);
      
      reflectedRay.origin = hitPoint;
      reflectedRay.dir = normalize((float3)(rand(&randomState), rand(&randomState), rand(&randomState)));
      if (dot(reflectedRay.dir, sphereNormal) < 0) {
        reflectedRay.dir = - reflectedRay.dir;
      }
      //reflectedRay = reflectRay(reflectedRay, hitPoint, sphereNormal);

      
      t = nearestIntersection(reflectedRay, sphere_count, spheres, &dummyID);
      if (t > 0) {
        if (dummyID == (sphere_count - 1)) {
          break;
        }
        mul *= dot(reflectedRay.dir, sphereNormal) * 0.7f;
        //compute color (assume white light)

      }
      else {
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
  float4 color = min(buffer[offset] * 255 * 6 / samplesCount, (float4)(255));
  pixels[offset] = (uchar4)(color.x, color.y, color.z, 255);
}