SYSTEM := $(shell uname -s)
BREW   := $(if $(findstring Darwin,$(SYSTEM)),$(shell brew --prefix))
CFLAGS += -g $(if $(BREW),-I$(BREW)/include)
LDLIBS += $(if $(BREW),-L$(BREW)/lib) -lcrypto

default: memtest
test: memtest
	valgrind --quiet --leak-check=full --show-leak-kinds=all --suppressions=valgrind.supp ./memtest $(PARAM)
clean:
	rm -rf memtest *.o *.a *.log *.tmp *.dSYM
