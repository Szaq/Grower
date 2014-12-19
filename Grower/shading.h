typedef enum {
  ShaderTypeDiffuse = 0,
  ShaderTypeEmitter,
} ShaderType;

typedef struct {
  float4 color;
  int shaderType;
  float IOR;//Index of refraction for transparent shaders
  float2 dummy;
} Material;

#define OBJECT_MATERIALS __global Material *

float4 surfaceColor(Material material, float3 localPoint, float3 incomingRay);
bool surfaceIsEmitter(Material material);


float4 surfaceColor(Material material, float3 localPoint, float3 incomingRay) {
  return material.color;
}

bool surfaceIsEmitter(Material material) {
  return material.shaderType == ShaderTypeEmitter;
}
