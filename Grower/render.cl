//
//  render.cl
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

__kernel void render(int width, int height, __global float *pixels, __global float4 *positions) {
  int x = get_global_idx(0);
  int y = get_global_idx(1);
  
  pixels[y * width + x] = 0.5f;
}