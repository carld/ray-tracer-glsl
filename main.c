#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <assert.h>
#include <unistd.h>

#include <GLFW/glfw3.h>

GLFWwindow *window;
GLFWmonitor *monitor;
const GLFWvidmode *mode;
GLint uniform_window_size;
GLint uniform_random_seed;
GLuint prog;

static void key_callback(GLFWwindow* window, int key /*glfw*/, int scancode, int action, int mods) {
  if (key == GLFW_KEY_ESCAPE) {
    glfwSetWindowShouldClose(window, 1);
  }
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

  int width = 600, height = 300;
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
  uniform_window_size = glGetUniformLocation(prog, "window_size");
  uniform_random_seed = glGetUniformLocation(prog, "random_seed");
  glUseProgram(prog);
  glUniform2f(uniform_window_size, width, height);
  uint _random_seed = arc4random();
  printf("Random seed: %ld\n", _random_seed);
  glUniform1f(uniform_random_seed, _random_seed);
  gl_program_info_log(stderr, prog);

  float lastTime = glfwGetTime();
  while (!glfwWindowShouldClose(window)) {
    glClearColor(0.2, 0.2, 0.2, 0.2);
    glClear(GL_COLOR_BUFFER_BIT);
    glRecti(-1,-1,1,1);
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
