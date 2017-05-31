#version 120

uniform vec2 window_size;
uniform float random_seed;

struct Ray {
  vec3 origin;
  vec3 direction;
};

const int mat_dielectric = 3;
const int mat_metal = 2;
const int mat_lambert = 1;

struct Material {
  vec3 albedo;

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

struct Camera {
  vec3 origin;
  vec3 lower_left_corner;
  vec3 horizontal;
  vec3 vertical;
};

Material gray_metal = Material(vec3(0.8, 0.8, 0.8), mat_metal);
Material gold_metal = Material(vec3(0.8, 0.6, 0.2), mat_metal);
Material lambert = Material(vec3(0.8, 0.8, 0.0), mat_lambert);

Sphere world[] = Sphere[](
  Sphere(vec3(1,0,-1), 0.5, gray_metal),
  Sphere(vec3(-1,0,-1), 0.5, gold_metal),
  Sphere(vec3(0,-100.5,-1), 100, lambert)
);

Camera camera = Camera(
  vec3(0.0,0.0,0.0),       /* origin */
  vec3(-2.0, -1.0, -1.0),  /* lower left corner */
  vec3(4.0, 0.0, 0.0),     /* horizontal */
  vec3(0.0, 2.0, 0.0)      /* vertical */
  );

float drand48(vec2 co) {
  return 2 * fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453) - 1;
}

float squared_length(vec3 v) {
  return v.x*v.x + v.y*v.y + v.z*v.z;
}

vec3 random_in_unit_sphere(vec3 p) {
  int n = 0;
  do {
    p = vec3(drand48(p.xy), drand48(p.zy), drand48(p.xz));
    n++;
  } while(squared_length(p) >= 1.0 && n < 20);
  return p;
  //return vec3(1,0,0);
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
  scattered = Ray(hit.p, reflected);
  attenuation = mat.albedo;
  return (dot(scattered.direction, hit.normal) > 0);
}

bool dispatch_scatter(in Ray r, HitRecord hit, out vec3 attenuation, out Ray scattered) {
  if(hit.mat.scatter_function == mat_dielectric) {
    /* dielectric */
  } else if (hit.mat.scatter_function == mat_metal) {
    /* metal */
    return metal_scatter(hit.mat, r, hit, attenuation, scattered);
  } else {
    /* lambert */
    return lambertian_scatter(hit.mat, r, hit, attenuation, scattered);
  }
}

Ray get_ray(Camera cam, float u, float v) {
  return Ray(cam.origin, cam.lower_left_corner + u * cam.horizontal + v * cam.vertical - cam.origin);
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

/* Check all objects in world for hit with ray */
bool world_hit(Ray r, float t_min, float t_max, out HitRecord hit) {
  HitRecord temp_hit;
  bool hit_anything = false;
  float closest_so_far = t_max;

  for (int i = 0; i < world.length(); i++) {
    if (sphere_hit(world[i], r, t_min, closest_so_far, temp_hit)) {
      hit_anything = true;
      if (temp_hit.t < closest_so_far) {
        hit = temp_hit;
        closest_so_far = temp_hit.t;
      }
    }
  }
  return hit_anything;
}

vec3 color(Ray r) {
  HitRecord hit;
  vec3 col = vec3(0, 0, 0);
  vec3 total_attenuation = vec3(1.0, 1.0, 1.0); /* reduction of light transmission */

  for (int bounce = 0; bounce < 8; bounce++) {

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
    int nsamples = 10;
    vec3 col = vec3(0,0,0);
    for (int s = 0; s < nsamples; s++) {
      float u = (gl_FragCoord.x + drand48(col.xy +s)) / window_size.x;
      float v = (gl_FragCoord.y + drand48(col.xz +s)) / window_size.y;
      Ray r = get_ray(camera, u, v);
      col += color(r);
    }
    col /= nsamples;
    col = vec3(sqrt(col.x),sqrt(col.y),sqrt(col.z));


    gl_FragColor = vec4(col, 1.0);
    //gl_FragColor = vec4(drand48(vec2(u,v)));
}
