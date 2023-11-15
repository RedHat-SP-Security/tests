CC=gcc
NAME=kafka-prog
FLAGS=$(shell pkg-config --cflags rdkafka)
LIBS=$(shell pkg-config --libs rdkafka)

all: $(NAME)

$(NAME): $(NAME).c
	gcc $(NAME).c -I/usr/include/librdkafka $(FLAGS) -o $(NAME) $(LIBS)

clean:
	rm -rf $(NAME)