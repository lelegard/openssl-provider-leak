SYSTEM := $(shell uname -s)
BREW   := $(if $(findstring Darwin,$(SYSTEM)),$(shell brew --prefix))
CFLAGS += -g $(if $(SYSROOT),-I$(SYSROOT)/include) $(if $(BREW),-I$(BREW)/include)
LDLIBS += $(if $(SYSROOT),$(addprefix -L,$(wildcard $(SYSROOT)/lib*))) $(if $(BREW),-L$(BREW)/lib) -lcrypto
ENV     = $(if $(SYSROOT),LD_LIBRARY_PATH="$(SYSROOT)/lib64:$(SYSROOT)/lib:$(LD_LIBRARY_PATH)")
default: memtest

clean:
	rm -rf memtest *.o *.a *.log *.tmp *.dSYM

test: memtest
ifeq ($(SYSTEM),Darwin)
	MallocStackLogging=1 leaks --atExit -- ./memtest $(PARAM)
else
	$(ENV) valgrind --quiet --leak-check=full --show-leak-kinds=all --suppressions=valgrind.supp ./memtest $(PARAM)
endif
