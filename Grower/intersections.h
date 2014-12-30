//NEEDS ray.h

static float intersectSphere(ray r, float4 s) {
  
  float3 centerToOriginVec = r.origin - s.xyz;
  
  float dottedDirs = dot(r.dir, centerToOriginVec);
  
  float delta = dottedDirs * dottedDirs + s.w * s.w - dot(centerToOriginVec, centerToOriginVec);
  
  if (delta < 0) {
    return -1;
  }
  
  if (delta == 0) {
    return -dottedDirs;
  }
  
  delta = sqrt(delta);
  
  float d1 = -dottedDirs - delta;
  float d2 = -dottedDirs + delta;
  
  //Warning - Case when we're inside sphere is not correctly  handled
  if (d2 < d1) {
    d1 = d2;
  }
  
  return d1;
}

static float nearestIntersection(ray r, int objectCount, OBJECT_GEOMETRIES objects, int *objID) {
  float minT = FLT_MAX;
  for (int id = 0; id < objectCount; id++) {
    float t = intersectSphere(r, objects[id]);
    if (t > 0.0f && t < minT && id != *objID) {
      minT = t;
      *objID = id;
    }
  }
  
  return (minT < FLT_MAX) ? minT : -1.0f;
}
