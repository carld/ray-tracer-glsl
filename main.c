#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <assert.h>
#include <unistd.h>

#include <GLFW/glfw3.h>

#include "camera.h"

int width = 600, height = 300;
GLFWwindow *window;
GLFWmonitor *monitor;
const GLFWvidmode *mode;
GLuint prog;
GLint uniform_window_size;
GLint uniform_random_seed;
GLint uniform_global_time;

GLint uniform_camera_origin;
GLint uniform_camera_lower_left_corner;
GLint uniform_camera_horizontal;
GLint uniform_camera_vertical;
GLint uniform_camera_lens_radius;

struct camera cam;
vec3 lookfrom = (vec3) {.x=5, .y=1, .z=5};
vec3 lookat   = (vec3) {.x=0, .y=0, .z=-1};
float dist_to_focus;
float aperture = 0.1;

void update_camera(struct camera *c) {
  /* reposition the camera */
  dist_to_focus = vec3_length(vec3_subtract_vec(lookfrom, lookat));
  camera_pos(&cam, lookfrom, lookat, (vec3){.x=0,.y=1,.z=0}, 20, (float)width/(float)height, aperture, dist_to_focus);

  glUniform3f(uniform_camera_origin, cam.origin.x, cam.origin.y, cam.origin.z);
  glUniform3f(uniform_camera_lower_left_corner, cam.lower_left_corner.x, cam.lower_left_corner.y, cam.lower_left_corner.z);
  glUniform3f(uniform_camera_horizontal, cam.horizontal.x, cam.horizontal.y, cam.horizontal.z);
  glUniform3f(uniform_camera_vertical, cam.vertical.x, cam.vertical.y, cam.vertical.z);
  glUniform1f(uniform_camera_lens_radius, cam.lens_radius);
}

static void key_callback(GLFWwindow* window, int key /*glfw*/, int scancode, int action, int mods) {
  switch(key){
  case GLFW_KEY_ESCAPE:
    glfwSetWindowShouldClose(window, 1);
    break;
  case GLFW_KEY_A:
    break;
  case GLFW_KEY_B:
    break;
  case GLFW_KEY_S:
    lookfrom.z /= 2;
    break;
  case GLFW_KEY_W:
    lookfrom.z *= 2;
    break;
  }
  update_camera(&cam);
}
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
  glUseProgram(prog);
  glViewport(0, 0, width, height);
  glUniform2f(uniform_window_size, width, height);
}
void info() {
  printf("OpenGL          %s\n", glGetString(GL_VERSION));
  printf("GLSL            %s\n", glGetString(GL_SHADING_LANGUAGE_VERSION));
  printf("Vendor          %s\n", glGetString(GL_VENDOR));
  printf("Renderer        %s\n", glGetString(GL_RENDERER));
  //printf("Extensions\n%s\n", glGetString(GL_EXTENSIONS));
}

static GLchar * read_file(const GLchar *fname, GLint *len) {
  struct stat buf;
  int fd = -1;
  GLchar *src = NULL;
  int bytes = 0;

  if (stat(fname, &buf) != 0)
    goto error;

  fd = open(fname, O_RDWR);
  if (fd < 0)
    goto error;

  src = calloc(buf.st_size + 1, sizeof (GLchar));

  bytes = read(fd, src, buf.st_size);
  if (bytes < 0)
    goto error;

  if (len) *len = buf.st_size;
  close(fd);
  return src;

error:
  perror(fname);
  exit(-2);
}

void gl_shader_info_log(FILE *fp, GLuint shader) {
  GLchar *info = NULL;
  GLint len = 0;
  glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
  if (len > 0) {
    info = calloc(len, sizeof(GLubyte));
    assert(info);
    glGetShaderInfoLog(shader, len, NULL, info);
    if (len > 0)
      fprintf(fp, "%s\n", info);

    if (info)
      free(info);
  }
}

void gl_program_info_log(FILE *fp, GLuint prog) {
  GLchar *info = NULL;
  GLint len = 0;
  glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &len);
  if (len > 0) {
    info = calloc(len, sizeof(GLchar));
    assert(info);

    glGetProgramInfoLog(prog, len, NULL, info);

    if (len > 0)
      fprintf(fp, "%s\n", info);

    if (info)
      free(info);
  }
}

int main(int argc, char *argv[]) {

  const char *shader_file = "fragment.glsl";
  if (!glfwInit()) {
    puts("Could not init glfw");
    exit(-1);
  }

  monitor = glfwGetPrimaryMonitor();
  mode    = glfwGetVideoMode(monitor);

  glfwWindowHint(GLFW_RED_BITS, mode->redBits);
  glfwWindowHint(GLFW_GREEN_BITS, mode->greenBits);
  glfwWindowHint(GLFW_BLUE_BITS, mode->blueBits);
  glfwWindowHint(GLFW_REFRESH_RATE, mode->refreshRate);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_DECORATED, GL_TRUE);
  glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);

  window = glfwCreateWindow(width, height, "ray tracer", NULL, NULL);
  if (!window) {
    glfwTerminate();
    puts("Could not create window");
    exit(-1);
  }

  glfwMakeContextCurrent(window);
  //glfwSetWindowUserPointer(window, app);
  glfwSwapInterval(1);
  glfwSetKeyCallback(window, key_callback);
  //glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

  info();

  /* Load the shader */
  GLint status = 0;
  int len = 0;
  const GLchar *src = read_file(shader_file, &len);
  int frag_shader_id = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(frag_shader_id, 1, &src, &len);
  glCompileShader(frag_shader_id);
  glGetShaderiv(frag_shader_id, GL_COMPILE_STATUS, &status);
  gl_shader_info_log(stdout, frag_shader_id);

  prog = glCreateProgram();
  glAttachShader(prog, frag_shader_id);
  glLinkProgram(prog);

  glUseProgram(prog);

  uniform_window_size = glGetUniformLocation(prog, "window_size");
  uniform_random_seed = glGetUniformLocation(prog, "random_seed");
  uniform_camera_origin = glGetUniformLocation(prog, "camera_origin");
  uniform_camera_lower_left_corner = glGetUniformLocation(prog, "camera_lower_left_corner");
  uniform_camera_horizontal = glGetUniformLocation(prog, "camera_horizontal");
  uniform_camera_vertical = glGetUniformLocation(prog, "camera_vertical");
  uniform_camera_lens_radius = glGetUniformLocation(prog, "camera_lens_radius");
  uniform_global_time = glGetUniformLocation(prog, "global_time");

  glUniform2f(uniform_window_size, width, height);
  uint _random_seed = arc4random();
  printf("Random seed: %ud\n", _random_seed);
  glUniform1f(uniform_random_seed, _random_seed);

  /* calculate the camera position. camera info is passed shader via uniforms */
  update_camera(&cam);

  gl_program_info_log(stderr, prog);

  float lastTime = glfwGetTime();
  while (!glfwWindowShouldClose(window)) {

    glUniform1f(uniform_global_time, glfwGetTime());

    glClearColor(0.2, 1.0, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glRecti(-1,-1,1,1); /* fragment shader is not run unless there's vertices in OpenGL 2? */
    glfwSwapBuffers(window);
    glfwPollEvents();

    if (glfwGetTime() > lastTime + 1.0) {
      lastTime = glfwGetTime();
    }
    usleep(100000);
  }

  glfwDestroyWindow(window);
  glfwTerminate();
}
