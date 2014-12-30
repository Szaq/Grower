#define OBJECT_GEOMETRY float4
#define OBJECT_GEOMETRIES __global float4 *

#define M_PI 3.14159265358979323846f

static float3 randomVector (PRNG *randomState) {
  return normalize((float3)(rand(randomState) - 0.5f, rand(randomState) - 0.5f, rand(randomState) - 0.5f));
}

static float3 randomVectorInHemisphere (float3 normal, PRNG *randomState) {
  float3 v = randomVector(randomState);
  if (dot(v, normal) < 0) {
    return -v;
  }
  return v;
}

/**
 *  Convert cartezian coordinate to spherical
 *
 *  @param cartezian (x, y, z)
 *
 *  @return (radius, inclination, azimuth)
 */
static float3 normalizedCartezianToSpherical(float3 cartezian) {
  return (float3)(1.0f,  acosf(cartezian.z), atan2(cartezian.y, cartezian.x));
}

static float3 sphericalToNormalizedCartezian(float3 spherical) {
  float sinIncl = sin(spherical.y);
  return (float3)(sinIncl *  cos(spherical.z),  sinIncl * sin(spherical.z), cos(spherical.y));
}