#include <math.h>
#include <stdlib.h>
#include "camera.h"

void camera_pos(camera *cam, vec3 lookfrom, vec3 lookat, vec3 vup, float vfov, float aspect, float aperture, float focus_dist) {
  cam->lens_radius = aperture / 2.0;
  float theta = vfov * M_PI / 180.0;
  float half_height = tan (theta / 2.0);
  float half_width = aspect * half_height;
  cam->origin = lookfrom;
  cam->w = unit_vector( vec3_subtract_vec( lookfrom, lookat ) );
  cam->u = unit_vector( vec3_cross( vup, cam->w ) );
  cam->v = vec3_cross( cam->w, cam->u );
  cam->lower_left_corner =
  vec3_subtract_vec(
    vec3_subtract_vec(
      vec3_subtract_vec(
        cam->origin,
        vec3_multiply_float( cam->u, half_width * focus_dist )),
      vec3_multiply_float( cam->v, half_height * focus_dist )),
    vec3_multiply_float( cam->w, focus_dist ));
  cam->horizontal  = vec3_multiply_float( cam->u,  2 * half_width * focus_dist );
  cam->vertical  = vec3_multiply_float( cam->v, 2 * half_height * focus_dist );
}

vec3 random_in_unit_disk() {
  vec3 p;
  do {
    p = vec3_subtract_vec(
          vec3_multiply_float( (vec3) { .x = drand48(), .y = drand48(), .z = 0 }, 2.0),
          (vec3) { .x = 1, .y = 1, .z = 0 }
    );
  } while (vec3_dot(p, p) >= 1.0);
  return p;
}
