//
//  render.cl
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

typedef struct {
  float3 origin;
  float padding1;
  //Normalized direction vector
  float3 dir;
  float padding2;
} ray;


float intersect_sphere(ray r, float4 s) {
  
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

float nearest_intersection(ray r, int sphere_count, __global float4 *spheres, int *objID) {
  float minT = FLT_MAX;
  for (int id = 0; id < sphere_count; id++) {
    float t = intersect_sphere(r, spheres[id]);
    if (t > 0.0f && t < minT && id != *objID) {
      minT = t;
      *objID = id;
    }
  }
  
  return (minT < FLT_MAX) ? minT : -1.0f;
}


//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, __global uchar4 *pixels,
                     int sphere_count, __global float4 *spheres) {
  
  
  //Generate eye ray
  int x = get_global_id(0);
  int y = get_global_id(1);

  float fovX = 3.14f / 6;
  float fovY = height * fovX / width;

  ray r;
  r.origin = (float3)(0, 0, 0);
  r.dir = normalize((float3)((2*x - width) * tan(fovX)/ width , (2*y-height)* tan(fovY) / height , 1));

  
  //Find nearest eye-ray intersection
  int objID = -1;
  float t = nearest_intersection(r, sphere_count, spheres, &objID);
  
  uchar4 color = (uchar4)(0,0,0, 255);
  if (t >= 0) {
    
    //Generate shadow-ray
    float3 sunPosition = (float3)(-200, 200, -200);
    ray lightRay;
    lightRay.origin = r.origin + r.dir * t;
    lightRay.dir = normalize(sunPosition - lightRay.origin);
    
    //Hardocded object color
    switch(objID % 4) {
      case 0:
        color = (uchar4)(255, 0, 0, 255);
        break;
      case 1:
        color = (uchar4)(255, 255, 0, 255);
        break;
      case 2:
        color = (uchar4)(0, 255, 0, 255);
        break;
      case 3:
        color = (uchar4)(0, 0, 255, 255);
        break;
    }
    
    //Check if anything is blocking the light
    float mul = 0.1f;
    int dummyID = objID;

    if (nearest_intersection(lightRay, sphere_count, spheres, &dummyID) < 0) {
      //compute color (assume white light)
      mul += dot(normalize(lightRay.origin - spheres[objID].xyz), lightRay.dir) * 0.9f;
    }
    
    color = (uchar4)(mul * color.x, mul * color.y, mul * color.z, 255);
  }
  
  pixels[(height - y - 1) * width + x] = color;
}