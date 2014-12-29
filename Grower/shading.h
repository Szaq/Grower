typedef enum {
  ShaderTypeDiffuse = 0,
  ShaderTypeEmitter,
  ShaderTypeGlossy,
  ShaderTypeMirror,
} ShaderType;

typedef struct {
  float4 color;
  int shaderType;
  float IOR;//Index of refraction for transparent and glossy shaders
  float roughness;///Roughness of glossy BRDF.
  float dummy;
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
 * Fresnel term in glossy BRDF.
 * @param viewDir - View direction.
 * @param lightDit - Light direction
 */
float glossyFresnel(float3 viewDir, float3 lightDir, float refractiveIndex) {
  float normalReflectance = fresnelReflectanceAtNormal(refractiveIndex);
  float3 halfVec = normalize(viewDir + lightDir);
  float a = 1 - dot(lightDir, halfVec);
  return normalReflectance + (1 - normalReflectance) * a * a * a * a * a;
}

/**
 *  Blin-Phong distribution term of a glossy BRDF.
 *
 *  @param normal           Surface normal
 *  @param microFacetNormal Microfacet normal
 *  @param alpha Slope of a microsurface.
 *
 *  @return Distribution term for glossy BRDF.
 */
float glossyDistributionBlinPhong(float3 normal, float3 microFacetNormal, float alpha) {
  return (alpha + 2.0f) * pow(dot(normal, microFacetNormal), alpha) / (2 * M_PI);
}

float blinToBeckmann(float alpha) {
  return sqrtf(2.0f / (alpha + 2.0f));
}

float beckmannToBlinn(float slope) {
  return 2 / (slope * slope) - 2;
}

float glossyDistributionBeckmann(float3 normal, float3 microFacetNormal, float slope) {
  float normalsDot = dot(normal, microFacetNormal);
  float expon = (normalsDot * normalsDot - 1) / (slope * slope - normalsDot * normalsDot);
  
  return exp(expon) / (M_PI * slope * slope * normalsDot * normalsDot * normalsDot * normalsDot);
}

/**
 *  Implicit geometry term of a glossy BRDF.
 *
 *  @param normal   Surface normal.
 *  @param lightDir Vector to light.
 *  @param viewDir  Vector to viewer.
 *
 *  @return Geometry term, which makes BRDF dependant only on Fresnel and Distribution term.
 */
float glossyGeometryImplicit(float3 normal, float3 lightDir, float3 viewDir) {
  return dot(normal, lightDir) * dot(normal, viewDir);
}

float3 glossyBRDF(float3 color, float3 normal, float3 microFacetNormal, float3 lightDir, float3 viewDir, float roughness,
                 float refractiveIndex) {
  return color
  * max(0.0f, glossyFresnel(viewDir, lightDir, refractiveIndex))
  * max(0.0f, glossyGeometryImplicit(normal, lightDir, viewDir))
  * max(0.0f, glossyDistributionBlinPhong(normal, microFacetNormal, beckmannToBlinn(roughness)))
  * 10 / (4 * dot(normal, lightDir) * dot (normal, viewDir));
}

float3 diffuseBRDF(float3 color, float3 normal, float3 lightDir) {
#warning Temporarily disabled diffuse BRDF
  return color * (float3)dot(lightDir, normal);
}


float3 BRDF(float3 color, float3 normal, float3 microFacetNormal, float3 lightDir, float3 eyeDir, Material material) {
  switch (material.shaderType) {
    case ShaderTypeDiffuse:
      return diffuseBRDF(color, normal, lightDir);
    case ShaderTypeGlossy:
      return glossyBRDF(color, normal, microFacetNormal, lightDir, -eyeDir, material.roughness, material.IOR);
    case ShaderTypeMirror:
      return color;
    case ShaderTypeEmitter:
      return color;
    default:
      break;
  }
  return color;
}

ray surfaceRay(Material material, float3 position, float3 normal, ray incomingRay, PRNG *randomState) {
  switch(material.shaderType) {
    case ShaderTypeDiffuse:
    case ShaderTypeGlossy:
      return randomRayInHemisphere(position, normal, randomState);
    case ShaderTypeMirror:
    case ShaderTypeEmitter:
      return reflectRay(incomingRay, position, normal);
    default:
      break;

  }
}
