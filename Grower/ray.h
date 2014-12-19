//NEEDS prng.cl

typedef struct {
  float3 origin;
  float padding1;
  //Normalized direction vector
  float3 dir;
  float padding2;
} ray;


ray reflectRay(ray r, float3 point, float3 normal);
ray eyeRay(int x, int y, int width, int height, PRNG *randomState);
ray randomRayInHemisphere(float3 position, float3 normal, PRNG *randomState);


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

ray randomRayInHemisphere(float3 position, float3 normal, PRNG *randomState) {
  ray r;
  r.origin = position;
  r.dir = normalize((float3)(rand(randomState) - 0.5f, rand(randomState) - 0.5f, rand(randomState) - 0.5f));
  
  if (dot(r.dir, normal) < 0) {
    r.dir = - r.dir;
  }
  return r;
}