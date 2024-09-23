# OpenSSL providers and resource cleanup

Since version 1.1.0, OpenSSL is supposed to automatically allocate the resources
it needs, and automatically free them on application termination (through an
`atexit()` handler).

Using `valgrind` on Linux, we observed that this behaviour is correct, except when
dealing with providers. An OpenSSL provider is loaded using `OSSL_PROVIDER_load()`
and unloaded using `OSSL_PROVIDER_unload()`. At the exit of an application, the
providers are not automatically unloaded and various memory leaks are observed.

This repository contains a sample program to illustrate the various possibilities
and mishaps, including memory leaks and segmentation faults.

In a simple application, it is easy to explicitly unload at the end of the program
the exact list of providers which were loaded. However, when developing a library
which uses OpenSSL, we have no control on the initialization and termination of the
program.

It is still possible to declare our own `atexit()` handler and then unload the
OpenSSL providers here. However, we have no control on the order of execution
of the various `atexit()` handlers, specifically the OpenSSL internal handler
which does the OpenSSL cleanup and our own handler which unloads the OpenSSL
providers. By specification, the `atexit()` handlers are called in reverse
order of registration. However, we have no control on when OpenSSL registers
its own handler and, therefore, we have no control on the execution order of
the `atexit()` handlers.

If the OpenSSL internal handler executes first, it deallocates all OpenSSL
internal resources (except the loaded providers). After this point, using
OpenSSL becomes impossible. Later, when our own handler tries to unload the
providers, the program may crash because we try to call an OpenSSL function
while OpenSSL is "terminated". We get a memory leak _and_ a crash.

We have observed that the crash happens only with OpenSSL 3.0. With OpenSSL 3.2
onwards, there is no crash when we try to unload a provider after OpenSSL cleanup.
However, the memory leak is still present and we do not know if the absence
of crash is dues to a new careful check in OpenSSL or just luck.

Note: When loading shared libraries, `dlopen()` keeps a few memory blocks. Because
we never unload shared libraries, this is expected and not significant for the
application memory management. In the test, these errors are suppressed using a
valgrind "suppression file". Therefore, any memory leak which is discussed here
is only due to OpenSSL, not `dlopen()`.

## OpenSSL 3.0.13, Ubuntu 24.04.1 LTS, x86_64 architecture

OpenSSL 3.0.13 (CPUINFO: OPENSSL_ia32cap=0x5ffaf3ffffebffff:0x427aa)

Observed behaviour:
- Do not call `OSSL_PROVIDER_unload()`
  - Memory leak (78 blocks)
- Call `OSSL_PROVIDER_unload()` at end of `main()`
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered before OpenSSL init.
  - Memory leak (81 blocks) and segmentation fault
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `OPENSSL_atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OPENSSL_cleanup()` at end of `main()`, do not call `OSSL_PROVIDER_unload()`
  - Memory leak (78 blocks)

## OpenSSL 3.0.13, Ubuntu 24.04.1 LTS, Arm64 architecture

OpenSSL 3.0.13 (CPUINFO: OPENSSL_armcap=0x3d)

Identical behaviours as x86_64 architecture, same OS and OpenSSL version.

## OpenSSL 3.2.2, Fedora 40, Arm64 architecture

OpenSSL 3.2.2 (CPUINFO: OPENSSL_armcap=0x8fd)

Observed behaviour:
- Do not call `OSSL_PROVIDER_unload()`
  - Memory leak (96 blocks)
- Call `OSSL_PROVIDER_unload()` at end of `main()`
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered before OpenSSL init.
  - Memory leak (96 blocks), *no segmentation fault*
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `OPENSSL_atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OPENSSL_cleanup()` at end of `main()`, do not call `OSSL_PROVIDER_unload()`
  - Memory leak (96 blocks)

## OpenSSL 3.3.2, Ubuntu 24.04.1 LTS, x86_64 architecture

OpenSSL 3.3.2 (CPUINFO: OPENSSL_ia32cap=0x5ffaf3ffffebffff:0x427aa)

To test this, OpenSSL 3.3.2 was recompiled on Ubuntu 24.04.1. See details below.

Observed behaviour:
- Do not call `OSSL_PROVIDER_unload()`
  - Memory leak (89 blocks)
- Call `OSSL_PROVIDER_unload()` at end of `main()`
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered before OpenSSL init.
  - Memory leak (89 blocks), *no segmentation fault*
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `OPENSSL_atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OPENSSL_cleanup()` at end of `main()`, do not call `OSSL_PROVIDER_unload()`
  - Memory leak (89 blocks)

## OpenSSL 3.3.2, macOS 15.0, Arm64 architecture

OpenSSL 3.3.2 (CPUINFO: OPENSSL_armcap=0x987d)

Because of the lack of `valgrind` support on macOS, the macOS tool `leaks` was used.

Observed behaviour:
- Do not call `OSSL_PROVIDER_unload()`
  - No memory leak
- Call `OSSL_PROVIDER_unload()` at end of `main()`
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered before OpenSSL init.
  - Memory leak (94 blocks), *no segmentation fault*
- Call `OSSL_PROVIDER_unload()` in `atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OSSL_PROVIDER_unload()` in `OPENSSL_atexit()` handler, registered after OpenSSL init.
  - No memory leak
- Call `OPENSSL_cleanup()` at end of `main()`, do not call `OSSL_PROVIDER_unload()`
  - No memory leak

This time, with OpenSSL 3.3.2, it seems that OpenSSL does the cleanup of the
loaded providers. Interestingly, the memory leaks are observed when we try to
unload the provider after the OpenSSL cleanup.

## Rebuilding OpenSSL on Linux

For information, the latest version of OpenSSL was rebuilt this way:
~~~
git clone https://github.com/openssl/openssl.git
cd openssl
git checkout openssl-3.3.2
./Configure --prefix=$HOME/opt/openssl
make install
~~~

And we build and run our tests like this:
~~~
make test SYSROOT=$HOME/opt/openssl PARAM=0
~~~
