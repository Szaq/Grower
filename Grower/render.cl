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
  
  float3 origin_center = r.origin - s.xyz;
   
  float dirs_dot = dot(r.dir, origin_center);
  float origin_center_len = length(origin_center);
  
  float delta = dirs_dot * dirs_dot + s.w * s.w - origin_center_len * origin_center_len;
  
  if (delta < 0) {
    return -1;
  }
  
  if (delta == 0) {
    return -dirs_dot;
  }
  
  delta = sqrt(delta);
  
  float d1 = -dirs_dot - delta;
  float d2 = -dirs_dot + delta;
  
  if ((d2 < d1 || d1 < 0) && d2 > 0) {
    d1 = d2;
  }
  
  return d1;
}

float nearest_intersection(ray r, int sphere_count, __global float4 *spheres, int *objID) {
  float minT = FLT_MAX;
  for (int id = 0; id < sphere_count; id++) {
    float t = intersect_sphere(r, spheres[id]);
    if (t > 0 && t < minT) {
      minT = t;
      *objID = id;
    }
  }
  
  return (minT < FLT_MAX) ? minT : -1.0f;
}


//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, __global uchar4 *pixels, int sphere_count, __global float4 *spheres) {
  int x = get_global_id(0);
  int y = get_global_id(1);

  float fovX = 3.14f / 3;
  float fovY = height * fovX / width;

  ray r;
  r.origin = (float3)(0, 0, 0);
  r.dir = normalize((float3)((2*x - width) * tan(fovX)/ width , (2*y-height)* tan(fovY) / height , 1));
  
  int objID = 0;
  uchar color = (uchar)(nearest_intersection(r, sphere_count, spheres, &objID));
//temporary invert pixels
  pixels[(height - y - 1) * width + x] = (uchar4)(color,color,color,255);
  
}