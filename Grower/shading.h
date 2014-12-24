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


/*
 * Compute basic fresnel reflectance at normal incident
 *
 * @param index Refractive index
 */
float fresnelReflectanceAtNormal(float index) {
  float partial = (1 - index) / (1 + index);
  return partial * partial;
}

/**
 * Fresnel term in Beckmann glossy equation.
 * @param viewDir - View direction.
 * @param lightDit - Light direction
 */
float glossyFresnelTerm(float3 viewDir, float3 lightDir, float refractiveIndex) {
  float normalReflectance = fresnelReflectanceAtNormal(refractiveIndex);
  float3 halfVec = normalize(viewDir + lightDir);
  float a = 1 - dot(lightDir, halfVec);
  return normalReflectance + (1 - normalReflectance) ;
}