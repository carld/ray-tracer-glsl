#version 120

#define M_PI 3.1415926535897932384626433832795

uniform vec2 window_size;
uniform float random_seed;

/* camera attributes are provided by application */
uniform vec3 camera_origin;
uniform vec3 camera_lower_left_corner;
uniform vec3 camera_horizontal;
uniform vec3 camera_vertical;
uniform float camera_lens_radius;

struct Ray {
  vec3 origin;
  vec3 direction;
};

const int mat_dielectric = 3;
const int mat_metal = 2;
const int mat_lambert = 1;

struct Material {
  vec3 albedo;
  float fuzz;
  float ref_idx;

  /* scatter function can be:
     1 = lambert
     2 = metal
     3 = dielectric
     */
  int scatter_function;
};

struct HitRecord {
  float t;
  vec3 p;
  vec3 normal;
  Material mat;
};

struct Sphere {
  vec3 center;
  float radius;
  Material mat;
};

Material gray_metal = Material(vec3(0.8, 0.8, 0.8), 0.0001, 0.0, mat_metal);
Material gold_metal = Material(vec3(0.8, 0.6, 0.2), 0.0001, 0.0, mat_metal);
Material dielectric = Material(vec3(0),                0.0, 1.5, mat_dielectric);
Material lambert    = Material(vec3(0.8, 0.8, 0.0),    0.0, 0.0, mat_lambert);

Sphere world[] = Sphere[](
  Sphere(vec3(1,0,-1), 0.5, gray_metal),
  Sphere(vec3(-1,0,-1), 0.5, gold_metal)
//  Sphere(vec3(0,0,1), 0.5, dielectric),
  //Sphere(vec3(0,0,1), -0.45, dielectric),
//  Sphere(vec3(0,-100.5,-1), 100, lambert)
);

/* returns a varying number between 0 and 1 */
float drand48(vec2 co) {
  return 2 * fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453) - 1;
}

vec3 random_in_unit_disk(vec2 co) {
  vec3 p;
  int n = 0;
  do {
    p = vec3(drand48(co.xy), drand48(co.yx), 0);
    n++;
  } while (dot(p,p) >= 1.0 && n < 3);
  return p;
}

float squared_length(vec3 v) {
  return v.x*v.x + v.y*v.y + v.z*v.z;
}

vec3 random_in_unit_sphere(vec3 p) {
  int n = 0;
  do {
    p = vec3(drand48(p.xy), drand48(p.zy), drand48(p.xz));
    n++;
  } while(squared_length(p) >= 1.0 && n < 3);
  return p;
}

bool lambertian_scatter(in Material mat, in Ray r, in HitRecord hit, out vec3 attenuation, out Ray scattered) {
  vec3 target = hit.p + hit.normal + random_in_unit_sphere(hit.p);
  scattered = Ray(hit.p, target - hit.p);
  attenuation = mat.albedo;
  return true;
}

vec3 reflect(in vec3 v, in vec3 n) {
  return v - 2 * dot(v, n) * n;
}

bool metal_scatter(in Material mat, in Ray r, in HitRecord hit, out vec3 attenuation, out Ray scattered) {
  vec3 reflected = reflect(normalize(r.direction), hit.normal);
  scattered = Ray(hit.p, reflected + mat.fuzz * random_in_unit_sphere(hit.p));
  attenuation = mat.albedo;
  return (dot(scattered.direction, hit.normal) > 0);
}

float schlick(in float cosine, in float ref_idx) {
  float r0 = (1 - ref_idx) / (1 + ref_idx);
  r0 = r0 * r0;
  return r0 + (1 - r0) * pow((1 - cosine), 5);
}

bool refract(in vec3 v, in vec3 n, in float ni_over_nt, out vec3 refracted) {
  vec3 uv = normalize(v);
  float dt = dot(uv, n);
  float discriminant = 1.0 - ni_over_nt * ni_over_nt * (1 - dt * dt);
  if (discriminant > 0) {
    refracted = ni_over_nt * (uv - n * dt) - n * sqrt(discriminant);
    return true;
  } else {
    return false;
  }
}

bool dielectric_scatter(in Material mat, in Ray r, in HitRecord hit, out vec3 attenuation, out Ray scattered) {
  vec3 outward_normal;
  vec3 reflected = reflect(r.direction, hit.normal);
  float ni_over_nt;
  attenuation = vec3(1.0, 1.0, 1.0);
  vec3 refracted;
  float reflect_prob;
  float cosine;
  if (dot(r.direction, hit.normal) > 0) {
    outward_normal = - hit.normal;
    ni_over_nt = mat.ref_idx;
    cosine = mat.ref_idx * dot(r.direction, hit.normal) / length(r.direction);
  } else {
    outward_normal = hit.normal;
    ni_over_nt = 1.0 / mat.ref_idx;
    cosine = - dot(r.direction, hit.normal) / length(r.direction);
  }
  if (refract(r.direction, outward_normal, ni_over_nt, refracted)) {
    reflect_prob = schlick(cosine, mat.ref_idx);
  } else {
    reflect_prob = 1.0;
  }

  if (drand48(r.direction.xy) < reflect_prob) {
    scattered = Ray(hit.p, reflected);
  } else {
    scattered = Ray(hit.p, refracted);
  }
  return true;
}

bool dispatch_scatter(in Ray r, HitRecord hit, out vec3 attenuation, out Ray scattered) {
  if(hit.mat.scatter_function == mat_dielectric) {
    return dielectric_scatter(hit.mat, r, hit, attenuation, scattered);
  } else if (hit.mat.scatter_function == mat_metal) {
    return metal_scatter(hit.mat, r, hit, attenuation, scattered);
  } else {
    return lambertian_scatter(hit.mat, r, hit, attenuation, scattered);
  }
}

Ray get_ray(float s, float t) {
  vec3 rd = camera_lens_radius * random_in_unit_disk(vec2(s,t));
  vec3 offset = vec3(s * rd.x, t * rd.y, 0);
  return Ray(camera_origin + offset, camera_lower_left_corner + s * camera_horizontal + t * camera_vertical - camera_origin - offset);
}

vec3 point_at_parameter(Ray r,float t) {
  return r.origin + t * r.direction;
}

/* Check hit between sphere and ray */
bool sphere_hit(Sphere sp, Ray r, float t_min, float t_max, out HitRecord hit) {
  vec3 oc = r.origin - sp.center;
  float a = dot(r.direction, r.direction);
  float b = dot(oc, r.direction);
  float c = dot(oc, oc) - sp.radius * sp.radius;
  float discriminant = b*b - a*c;
  if (discriminant > 0) {
    float temp = (-b - sqrt(b*b-a*c)) /a;
    if (temp < t_max && temp > t_min) {
      hit.t = temp;
      hit.p = point_at_parameter(r, hit.t);
      hit.normal = (hit.p - sp.center) / sp.radius;
      hit.mat = sp.mat;
      return true;
    }
    temp = (-b + sqrt(b*b-a*c)) /a;
    if (temp < t_max && temp > t_min) {
      hit.t = temp;
      hit.p = point_at_parameter(r, hit.t);
      hit.normal = (hit.p - sp.center) / sp.radius;
      hit.mat = sp.mat;
      return true;
    }
  }
  return false;
}

bool plane_hit(Ray r, float t_min, float t_max, out HitRecord hit) {
  float t = (-0.5 - r.origin.y) / r.direction.y;
  if (t < t_min || t > t_max) return false;
  hit.t = t;
  hit.p = point_at_parameter(r, t);
  hit.mat = gray_metal;
  hit.normal = vec3(0, 1, 0);
  return true;
}

/* Check all objects in world for hit with ray */
bool world_hit(Ray r, float t_min, float t_max, out HitRecord hit) {
  HitRecord temp_hit;
  bool hit_anything = false;
  float closest_so_far = t_max;

  for (int i = 0; i < world.length(); i++) {
    if (sphere_hit(world[i], r, t_min, closest_so_far, temp_hit)) {
      hit_anything = true;
      hit = temp_hit;
      closest_so_far = temp_hit.t;
    }
  }
  if (plane_hit(r, t_min, closest_so_far, temp_hit)) {
    hit_anything = true;
    hit = temp_hit;
  }

  return hit_anything;
}

vec3 color(Ray r) {
  HitRecord hit;
  vec3 col = vec3(0, 0, 0); /* visible color */
  vec3 total_attenuation = vec3(1.0, 1.0, 1.0); /* reduction of light transmission */

  for (int bounce = 0; bounce < 4; bounce++) {

    if (world_hit(r, 0.001, 1.0 / 0.0, hit)) {
      /* create a new reflected ray */
      Ray scattered;
      vec3 local_attenuation;

      if (dispatch_scatter(r, hit, local_attenuation, scattered)) {
        total_attenuation *= local_attenuation;
        r = scattered;
      } else {
        total_attenuation *= vec3(0,0,0);
      }
    } else {
      /* background hit (light source) */
      vec3 unit_dir = normalize(r.direction);
      float t = 0.5 * (unit_dir.y + 1.0);
      col = total_attenuation * ((1.0-t)*vec3(1.0,1.0,1.0)+t*vec3(0.5,0.7,1.0));
      break;
    }
  }
  return col;
}

void main() {
    vec3 col = vec3(0,0,0);
    float u, v;
    Ray r;
    const int nsamples = 16;
    for (int s = 0; s < nsamples; s++) {
      u = (gl_FragCoord.x + drand48(col.xy + s)) / window_size.x;
      v = (gl_FragCoord.y + drand48(col.xz + s)) / window_size.y;
      r = get_ray(u, v);
      col += color(r);
    }
    col /= nsamples;
    col = vec3(sqrt(col.x),sqrt(col.y),sqrt(col.z));

    gl_FragColor = vec4(col, 1.0);
}
