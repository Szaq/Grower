typedef enum {
  ShaderTypeDiffuse = 0,
  ShaderTypeEmitter,
  ShaderTypeGlossy,
  ShaderTypeMirror,
  ShaderTypeTransparent,
} ShaderType;

typedef struct {
  float4 color;
  int shaderType;
  float IOR;//Index of refraction for transparent and glossy shaders
  float roughness;///Roughness of glossy BRDF.
  float dummy;
} Material;

#define OBJECT_MATERIALS __global Material *

static float4 surfaceColor(Material material, float3 localPoint, float3 incomingRay) {
  return material.color;
}

static bool surfaceIsEmitter(Material material) {
  return material.shaderType == ShaderTypeEmitter;
}


/*
 * Compute basic fresnel reflectance at normal incident
 *
 * @param index Refractive index
 */
static float fresnelReflectanceAtNormal(float index) {
  float partial = (1 - index) / (1 + index);
  return partial * partial;
}

/**
 * Fresnel term in glossy BRDF.
 * @param viewDir - View direction.
 * @param lightDit - Light direction
 */
static float glossyFresnel(float3 viewDir, float3 lightDir, float refractiveIndex) {
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
static float glossyDistributionBlinPhong(float3 normal, float3 microFacetNormal, float alpha) {
  return (alpha + 2.0f) * pow(dot(normal, microFacetNormal), alpha) / (2 * M_PI);
}

static float blinToBeckmann(float alpha) {
  return sqrtf(2.0f / (alpha + 2.0f));
}

static float beckmannToBlinn(float slope) {
  return 2 / (slope * slope) - 2;
}

static float glossyDistributionBeckmann(float3 normal, float3 microFacetNormal, float slope) {
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
static float glossyGeometryImplicit(float3 normal, float3 lightDir, float3 viewDir) {
  return dot(normal, lightDir) * dot(normal, viewDir);
}

static float3 glossyBRDF(float3 color, float3 normal, float3 lightDir, float3 viewDir, float roughness,
                 float refractiveIndex) {
  float3 microFacetNormal = normalize(lightDir + viewDir);
  return color
  * max(0.0f, glossyFresnel(viewDir, lightDir, refractiveIndex))
  * max(0.0f, glossyGeometryImplicit(microFacetNormal, lightDir, viewDir))
  * max(0.0f, glossyDistributionBlinPhong(normal, microFacetNormal, beckmannToBlinn(roughness)))
   / (4 * dot(normal, lightDir) * dot (normal, viewDir));
}

static float3 diffuseBRDF(float3 color, float3 normal, float3 lightDir) {
  return color * (float3)dot(lightDir, normal);
}


static float3 BRDF(float3 color, float3 normal, float3 lightDir, float3 eyeDir, Material material) {
  switch (material.shaderType) {
    case ShaderTypeDiffuse:
      return diffuseBRDF(color, normal, lightDir);
    case ShaderTypeGlossy:
      return glossyBRDF(color, normal, lightDir, -eyeDir, material.roughness, material.IOR);
    case ShaderTypeMirror:
    case ShaderTypeTransparent:
      return color;
    case ShaderTypeEmitter:
      return color;
    default:
      break;
  }
  return color;
}

static ray surfaceRay(Material material, float3 position, float3 normal, ray incomingRay, PRNG *randomState) {
  switch(material.shaderType) {
    case ShaderTypeDiffuse:
    case ShaderTypeGlossy:
      return randomRayInHemisphere(position, normal, randomState);
    case ShaderTypeMirror:
    case ShaderTypeEmitter:
      return reflectRay(incomingRay, position, normal);
    case ShaderTypeTransparent:
      if (dot(incomingRay.dir, normal) < 0) {
          return refractRay(incomingRay, position, normal, 1.0f / material.IOR);
      }
      else {
        return refractRay(incomingRay, position, normal, material.IOR);
      }
      
    default:
      break;

  }
  return incomingRay;
}
