all:
	zig build

test:
	zig build test

coverage:
	zig build coverage

run:
	zig build run

run-selftest:
	zig build run-selftest

debug:
	zig build debug

kernel:
	zig build kernel

image:
	zig build image

size:
	zig build size

check-tools:
	zig build check-tools

clean:
	zig build clean

fclean: clean
	zig build clean

re: fclean all

.PHONY: all test coverage run run-selftest debug kernel image size check-tools clean fclean re
