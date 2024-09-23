CFLAGS += -g
LDLIBS += -lcrypto
default: memtest
test: memtest
	valgrind --quiet --leak-check=full --show-leak-kinds=all --suppressions=valgrind.supp ./memtest $(PARAM)
