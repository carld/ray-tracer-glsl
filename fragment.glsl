#version 120

uniform vec2 window_size;

struct Ray {
  vec3 origin;
  vec3 direction;
};

struct HitRecord {
  float t;
  vec3 p;
  vec3 normal;
};

struct Sphere {
  vec3 center;
  float radius;
};

Sphere world[2] = Sphere[](
  Sphere(vec3(0,0,-1),0.5),
  Sphere(vec3(0,-100.5,-1),100)
);

vec3 point_at_parameter(Ray r,float t) {
  return r.origin + t * r.direction;
}

bool sphere_hit(Sphere sp, Ray r, float t_min, float t_max, out HitRecord rec) {
  vec3 oc = r.origin - sp.center;
  float a = dot(r.direction, r.direction);
  float b = dot(oc, r.direction);
  float c = dot(oc, oc) - sp.radius * sp.radius;
  float discriminant = b*b - a*c;
  if (discriminant > 0) {
    float temp = (-b - sqrt(b*b-a*c)) /a;
    if (temp < t_max && temp > t_min) {
      rec.t = temp;
      rec.p = point_at_parameter(r, rec.t);
      rec.normal = (rec.p - sp.center) / sp.radius;
      return true;
    }
    temp = (-b + sqrt(b*b-a*c)) /a;
    if (temp < t_max && temp > t_min) {
      rec.t = temp;
      rec.p = point_at_parameter(r, rec.t);
      rec.normal = (rec.p - sp.center) / sp.radius;
      return true;
    }
  }
  return false;
}

bool hit(Ray r, float t_min, float t_max, out HitRecord rec) {
  HitRecord temp_rec;
  bool hit_anything = false;
  float closest_so_far = t_max;
  for (int i = 0; i < world.length(); i++) {
    if (sphere_hit(world[i], r, t_min, closest_so_far, temp_rec)) {
      hit_anything = true;
      closest_so_far = temp_rec.t;
      rec = temp_rec;
    }
  }
  return hit_anything;
}

vec3 color(Ray r) {
  HitRecord rec;
  if (hit(r, 0.0, 1.0 / 0.0, rec)) {
    return 0.5 * vec3(rec.normal.x+1, rec.normal.y+1, rec.normal.z+1);
  } else {
    vec3 unit_dir = normalize(r.direction);
    float t = 0.5 * (unit_dir.y + 1.0);
    return (1.0-t)*vec3(1.0,1.0,1.0)+t*vec3(0.5,0.7,1.0);
  }
}

vec3 lower_left_corner = vec3(-2.0,-1.0,-1.0);
vec3 horizontal = vec3(4.0,0.0,0.0);
vec3 vertical = vec3(0.0,2.0,0.0);
vec3 origin = vec3(0.0,0.0,0.0);

void main() {
    float u = gl_FragCoord.x / window_size.x;
    float v = gl_FragCoord.y / window_size.y;
    Ray r = Ray(origin, lower_left_corner + u * horizontal + v * vertical);
    vec3 col = color(r);
    gl_FragColor = vec4(col, 1.0);
}
