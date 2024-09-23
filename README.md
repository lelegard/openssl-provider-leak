## OpenSSL providers and resource cleanup

Since version 1.1.0, OpenSSL is supposed to automatically allocate the resources
it needs, and automatically free them on application termination (through an
`atexit()` handler.

Using `valgrind` on Linux, we observed that this behaviour is correct, except when
dealing with providers. An OpenSSL provider is loaded using `OSSL_PROVIDER_load()`
and unloaded using `OSSL_PROVIDER_unload()`. At the exit of an application, the
providers are not automatically unloaded and various memory leaks are observed.

This repository contains a sample program to illustrate the various possibilities
and possible mistakes, including memory leaks and segmentation faults.

Configuration:
- Ubuntu 24.04.1 LTS
- x86_64 architecture
- OpenSSL 3.0.13 (CPUINFO: OPENSSL_ia32cap=0x5ffaf3ffffebffff:0x427aa)

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

Notes:
- When loading shared libraries, `dlopen()` keeps a few memory blocks. Because we never unload
  shared libraries, this is expected and not significant for the application memory management.
  These errors are suppressed using a valgrind "suppression file". Therefore, any memory leak
  which is discussed here is only due to OpenSSL, not `dlopen()`.
