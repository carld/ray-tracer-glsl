
PLATFORM = $(shell uname)
REV = $(shell git rev-parse HEAD)

$(info Building revision $(REV) for $(PLATFORM))

ifeq (Linux,$(PLATFORM))
	CC = gcc
	CFLAGS += -DLINUX=1
	LFLAGS += -lGLU -lGL -lGLEW
	LFLAGS += $(GLFW) -lrt -lm -ldl -lX11 -lpthread -lXrandr -lXinerama -lXxf86vm -lXcursor -lXi
	GLFW_TAG = 3.2.1
endif

ifeq (Darwin,$(PLATFORM))
	CFLAGS += -DDARWIN=1 -O3
	CFLAGS += -I/usr/local/include/GLFW
	LFLAGS += -L/usr/local/lib
	GLFW_TAG = 3.2.1
endif

CFLAGS += -g -ggdb -Wall -D_GNU_SOURCE
LFLAGS += -lglfw -framework Cocoa -framework OpenGL -framework IOKit -framework CoreVideo

SRC += $(wildcard *.c)
OBJ = $(SRC:.c=.o)
BIN = raytracer

.PHONY: clean prebuild

all: prebuild $(BIN)

prebuild:

.c.o:  $(SRC)
	$(CC) -c $(CFLAGS) $< -o $@

$(BIN): $(OBJ)
	$(CC) -o $@ $(OBJ)  $(LFLAGS)

clean:
	rm -vf $(BIN) $(OBJ)
