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
  
  if (d2 < d1 && d2 > 0) {
    d1 = d2;
  }
  
  return d1;
}


//sphere is defined by it's position float3 and radius
__kernel void render(int width, int height, __global uchar4 *pixels, __global float4 *spheres) {
  int x = get_global_id(0);
  int y = get_global_id(1);
  
  ray r;
  r.origin = (float3)(x, y, 0);
  r.dir = (float3)(0, 0, 1);
  
  float4 s = (float4)(0, 0, 200, 100);
  
  uchar4 color = intersect_sphere(r, s) > 0 ? (uchar4)(255, 255, 255, 255) : (uchar4)(0,0,0,255);
  
  pixels[y * width + x] = color;
  
}