#define OBJECT_GEOMETRY float4
#define OBJECT_GEOMETRIES __global float4 *

#define M_PI 3.14159265358979323846f

float3 randomVector (PRNG *randomState) {
  return normalize((float3)(rand(randomState) - 0.5f, rand(randomState) - 0.5f, rand(randomState) - 0.5f));
}

float3 randomVectorInHemisphere (float3 normal, PRNG *randomState) {
  float3 v = randomVector(randomState);
  if (dot(v, normal) < 0) {
    return -v;
  }
  return v;
}