//NEEDS prng.cl

typedef struct {
  float3 origin;
  float padding1;
  //Normalized direction vector
  float3 dir;
  float padding2;
} ray;


static ray reflectRay(ray r, float3 point, float3 normal) {
  ray reflectedRay;
  reflectedRay.origin = point;
  reflectedRay.dir = normalize(r.dir - 2 * dot(r.dir, normal) * normal );
  return reflectedRay;
}

/**
 *  Calculate perfect refracted ray.
 *
 *  @param r       Ray to refract
 *  @param point   Point in global space
 *  @param normal  Object's normal.
 *  @param indexRation Ratio of incoming material IOR, to outgoing material IOR.
 *
 *  @return Refracted ray, or (empty ray if total internal reflection occured)
 */
static ray refractRay(ray r, float3 point, float3 normal, float indexes) {
  float dots = dot(r.dir, normal);
  float sin2t = indexes * indexes * (1.0f - dots * dots);
  
  ray refractedRay;
  refractedRay.origin = point;
  if (sin2t <= 1.0f) {
    refractedRay.dir = normalize(indexes * r.dir  + (indexes * dots  - sqrt(1.0f - sin2t)) * normal);
  }
  else {
    refractedRay.dir = (float3)(0);
  }
  return refractedRay;
}


static ray eyeRay(int x, int y, int width, int height, PRNG *randomState) {
  float fovX = M_PI / 5;
  float fovY = height * fovX / width;
  
  ray r;
  r.origin = (float3)(0, 0, 0);
  r.dir = normalize((float3)((2 * (x + rand(randomState) - 0.5f) - width)  * tan(fovX) / width ,
                             (2 * (y + rand(randomState) - 0.5f) - height) * tan(fovY) / height ,
                             1));
  return r;
}

static ray randomRayInHemisphere(float3 position, float3 normal, PRNG *randomState) {
  ray r;
  r.origin = position;
#ifdef newBRDF
  float cosAlpha = asinf(rand(randomState)) * 2.0f / M_PI;
  float radius = sqrtf( 1.0f / (cosAlpha * cosAlpha) - 1.0f);
  float theta = rand(randomState) * 2.0f * M_PI;
  
  float3 perp = normalize(cross(normal, (float3)(1,.5,0.001f)));
  float3 perp2 = normalize(cross(normal, perp2));
  
  r.dir = normalize(normal + radius * (cos(theta) * perp + sin(theta) * perp2));
#else
  r.dir = randomVectorInHemisphere(normal, randomState);
#endif
  
  return r;
}