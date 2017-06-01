#ifndef VEC3_H
#define VEC3_H

#include <math.h>

typedef struct vec3 {
  float x;
  float y;
  float z;
} vec3;

float vec3_length(vec3 v);
float vec3_squared_length(vec3 v);
vec3 vec3_multiply(vec3 v1, int n);
vec3 vec3_multiply_float(vec3 v1, float n);
vec3 vec3_multiply_vec(vec3 v1, vec3 v2);
vec3 vec3_divide(vec3 v1, int n);
vec3 vec3_divide_float(vec3 v1, float n);
vec3 vec3_add_vec(vec3 v1, vec3 v2);
vec3 vec3_subtract_vec(vec3 v1, vec3 v2);
vec3 vec3_subtract_float(vec3 v1, float n);
vec3 unit_vector(vec3 v1);
float vec3_dot(vec3 v1, vec3 v2);
vec3 vec3_cross(vec3 v1, vec3 v2);

#endif
