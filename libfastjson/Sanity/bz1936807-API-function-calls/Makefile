TARGET=main
CC=gcc
LIBFASTJSON_FLAGS=$(shell pkg-config --cflags libfastjson)
LIBFASTJSON_LIBS=$(shell pkg-config --libs libfastjson)

all: $(TARGET)

$(TARGET): $(TARGET).c
	$(CC) $(LIBFASTJSON_FLAGS) -o $(TARGET) $(TARGET).c $(LIBFASTJSON_LIBS)

test:
	./$(TARGET)

clean:
	rm -rf $(TARGET)
