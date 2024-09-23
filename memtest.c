// Test memory allocation in OpenSSL providers.
// Parameter must be one of:
//   0: do not unload provider (default)
//   1: unload provider at end of main
//   2: unload provider in atexit() handler, declared before OpenSSL init.
//   3: unload provider in atexit() handler, declared after OpenSSL init.
//   4: unload provider in OPENSSL_atexit() handler, declared after OpenSSL init.
//   5: call OPENSSL_cleanup() at end of main, do not unload provider

#include <stdio.h>
#include <stdlib.h>
#include <openssl/opensslv.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/core_names.h>
#include <openssl/provider.h>

OSSL_PROVIDER* legacy = NULL;

void exit_handler(void)
{
    if (legacy != NULL) {
        OSSL_PROVIDER_unload(legacy);
        legacy = NULL;
    }
}

int main(int argc, char* argv[])
{
    const int param = argc < 2 ? 0 : atoi(argv[1]);

    if (param == 2) {
        atexit(exit_handler);
    }

    ERR_load_crypto_strings();
    OpenSSL_add_all_algorithms();
    printf("OpenSSL %s (%s)\n", OpenSSL_version(OPENSSL_FULL_VERSION_STRING), OpenSSL_version(OPENSSL_CPU_INFO));

    if (param == 3) {
        atexit(exit_handler);
    }

    if (param == 4) {
        OPENSSL_atexit(exit_handler);
    }

    if ((legacy = OSSL_PROVIDER_load(NULL, "legacy")) == NULL) {
        ERR_print_errors_fp(stderr);
        return EXIT_FAILURE;
    }

    if (param == 1 && legacy != NULL) {
        OSSL_PROVIDER_unload(legacy);
        legacy = NULL;
    }

    if (param == 5) {
        OPENSSL_cleanup();
    }
}
