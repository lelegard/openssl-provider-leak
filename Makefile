SYSTEM := $(shell uname -s)
BREW   := $(if $(findstring Darwin,$(SYSTEM)),$(shell brew --prefix))
CFLAGS += -g $(if $(BREW),-I$(BREW)/include)
LDLIBS += $(if $(BREW),-L$(BREW)/lib) -lcrypto

default: memtest

clean:
	rm -rf memtest *.o *.a *.log *.tmp *.dSYM

test: memtest
ifeq ($(SYSTEM),Darwin)
	MallocStackLogging=1 leaks --atExit -- ./memtest $(PARAM)
else
	valgrind --quiet --leak-check=full --show-leak-kinds=all --suppressions=valgrind.supp ./memtest $(PARAM)
endif
