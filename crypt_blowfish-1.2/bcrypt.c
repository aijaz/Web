#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <errno.h>
#ifndef __set_errno
#define __set_errno(val) errno = (val)
#endif

#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <sys/times.h>

#define CRYPT_OUTPUT_SIZE		(7 + 22 + 31 + 1)
#define CRYPT_GENSALT_OUTPUT_SIZE	(7 + 22 + 1)

#if defined(__GLIBC__) && defined(_LIBC)
#define __SKIP_GNU
#endif
#include "ow-crypt.h"

#include "crypt_blowfish.h"
#include "crypt_gensalt.h"

#if defined(__GLIBC__) && defined(_LIBC)
/* crypt.h from glibc-crypt-2.1 will define struct crypt_data for us */
#include "crypt.h"
extern char *__md5_crypt_r(const char *key, const char *salt,
	char *buffer, int buflen);
/* crypt-entry.c needs to be patched to define __des_crypt_r rather than
 * __crypt_r, and not define crypt_r and crypt at all */
extern char *__des_crypt_r(const char *key, const char *salt,
	struct crypt_data *data);
extern struct crypt_data _ufc_foobar;
#endif

static int _crypt_data_alloc(void **data, int *size, int need)
{
	void *updated;

	if (*data && *size >= need) return 0;

	updated = realloc(*data, need);

	if (!updated) {
#ifndef __GLIBC__
		/* realloc(3) on glibc sets errno, so we don't need to bother */
		__set_errno(ENOMEM);
#endif
		return -1;
	}

#if defined(__GLIBC__) && defined(_LIBC)
	if (need >= sizeof(struct crypt_data))
		((struct crypt_data *)updated)->initialized = 0;
#endif

	*data = updated;
	*size = need;

	return 0;
}

static char *_crypt_retval_magic(char *retval, const char *setting,
	char *output, int size)
{
	if (retval)
		return retval;

	if (_crypt_output_magic(setting, output, size))
		return NULL; /* shouldn't happen */

	return output;
}

#if defined(__GLIBC__) && defined(_LIBC)
/*
 * Applications may re-use the same instance of struct crypt_data without
 * resetting the initialized field in order to let crypt_r() skip some of
 * its initialization code.  Thus, it is important that our multiple hashing
 * algorithms either don't conflict with each other in their use of the
 * data area or reset the initialized field themselves whenever required.
 * Currently, the hashing algorithms simply have no conflicts: the first
 * field of struct crypt_data is the 128-byte large DES key schedule which
 * __des_crypt_r() calculates each time it is called while the two other
 * hashing algorithms use less than 128 bytes of the data area.
 */

char *__crypt_rn(__const char *key, __const char *setting,
	void *data, int size)
{
	if (setting[0] == '$' && setting[1] == '2')
		return _crypt_blowfish_rn(key, setting, (char *)data, size);
	if (setting[0] == '$' && setting[1] == '1')
		return __md5_crypt_r(key, setting, (char *)data, size);
	if (setting[0] == '$' || setting[0] == '_') {
		__set_errno(EINVAL);
		return NULL;
	}
	if (size >= sizeof(struct crypt_data))
		return __des_crypt_r(key, setting, (struct crypt_data *)data);
	__set_errno(ERANGE);
	return NULL;
}

char *__crypt_ra(__const char *key, __const char *setting,
	void **data, int *size)
{
	if (setting[0] == '$' && setting[1] == '2') {
		if (_crypt_data_alloc(data, size, CRYPT_OUTPUT_SIZE))
			return NULL;
		return _crypt_blowfish_rn(key, setting, (char *)*data, *size);
	}
	if (setting[0] == '$' && setting[1] == '1') {
		if (_crypt_data_alloc(data, size, CRYPT_OUTPUT_SIZE))
			return NULL;
		return __md5_crypt_r(key, setting, (char *)*data, *size);
	}
	if (setting[0] == '$' || setting[0] == '_') {
		__set_errno(EINVAL);
		return NULL;
	}
	if (_crypt_data_alloc(data, size, sizeof(struct crypt_data)))
		return NULL;
	return __des_crypt_r(key, setting, (struct crypt_data *)*data);
}

char *__crypt_r(__const char *key, __const char *setting,
	struct crypt_data *data)
{
	return _crypt_retval_magic(
		__crypt_rn(key, setting, data, sizeof(*data)),
		setting, (char *)data, sizeof(*data));
}

char *__crypt(__const char *key, __const char *setting)
{
	return _crypt_retval_magic(
		__crypt_rn(key, setting, &_ufc_foobar, sizeof(_ufc_foobar)),
		setting, (char *)&_ufc_foobar, sizeof(_ufc_foobar));
}
#else
char *crypt_rn(const char *key, const char *setting, void *data, int size)
{
	return _crypt_blowfish_rn(key, setting, (char *)data, size);
}

char *crypt_ra(const char *key, const char *setting,
	void **data, int *size)
{
	if (_crypt_data_alloc(data, size, CRYPT_OUTPUT_SIZE))
		return NULL;
	return _crypt_blowfish_rn(key, setting, (char *)*data, *size);
}

char *crypt_r(const char *key, const char *setting, void *data)
{
	return _crypt_retval_magic(
		crypt_rn(key, setting, data, CRYPT_OUTPUT_SIZE),
		setting, (char *)data, CRYPT_OUTPUT_SIZE);
}

char *crypt(const char *key, const char *setting)
{
	static char output[CRYPT_OUTPUT_SIZE];

	return _crypt_retval_magic(
		crypt_rn(key, setting, output, sizeof(output)),
		setting, output, sizeof(output));
}

#define __crypt_gensalt_rn crypt_gensalt_rn
#define __crypt_gensalt_ra crypt_gensalt_ra
#define __crypt_gensalt crypt_gensalt
#endif

char *__crypt_gensalt_rn(const char *prefix, unsigned long count,
	const char *input, int size, char *output, int output_size)
{
	char *(*use)(const char *_prefix, unsigned long _count,
		const char *_input, int _size,
		char *_output, int _output_size);

	/* This may be supported on some platforms in the future */
	if (!input) {
		__set_errno(EINVAL);
		return NULL;
	}

	if (!strncmp(prefix, "$2a$", 4) || !strncmp(prefix, "$2y$", 4))
		use = _crypt_gensalt_blowfish_rn;
	else
	if (!strncmp(prefix, "$1$", 3))
		use = _crypt_gensalt_md5_rn;
	else
	if (prefix[0] == '_')
		use = _crypt_gensalt_extended_rn;
	else
	if (!prefix[0] ||
	    (prefix[0] && prefix[1] &&
	    memchr(_crypt_itoa64, prefix[0], 64) &&
	    memchr(_crypt_itoa64, prefix[1], 64)))
		use = _crypt_gensalt_traditional_rn;
	else {
		__set_errno(EINVAL);
		return NULL;
	}

	return use(prefix, count, input, size, output, output_size);
}

char *__crypt_gensalt_ra(const char *prefix, unsigned long count,
	const char *input, int size)
{
	char output[CRYPT_GENSALT_OUTPUT_SIZE];
	char *retval;

	retval = __crypt_gensalt_rn(prefix, count,
		input, size, output, sizeof(output));

	if (retval) {
		retval = strdup(retval);
#ifndef __GLIBC__
		/* strdup(3) on glibc sets errno, so we don't need to bother */
		if (!retval)
			__set_errno(ENOMEM);
#endif
	}

	return retval;
}

char *__crypt_gensalt(const char *prefix, unsigned long count,
	const char *input, int size)
{
	static char output[CRYPT_GENSALT_OUTPUT_SIZE];

	return __crypt_gensalt_rn(prefix, count,
		input, size, output, sizeof(output));
}

#if defined(__GLIBC__) && defined(_LIBC)
weak_alias(__crypt_rn, crypt_rn)
weak_alias(__crypt_ra, crypt_ra)
weak_alias(__crypt_r, crypt_r)
weak_alias(__crypt, crypt)
weak_alias(__crypt_gensalt_rn, crypt_gensalt_rn)
weak_alias(__crypt_gensalt_ra, crypt_gensalt_ra)
weak_alias(__crypt_gensalt, crypt_gensalt)
weak_alias(crypt, fcrypt)
#endif


int main(int argc, char **argv)
{
    /*
      Two args: crypts arg1 with arg2 (session)
      prints out result of crypt.
      Up to caller to see if they match
    */

    int cost = 10;

    if (argc != 3 && argc != 2)
        return 1;


    if (argc == 3 && strlen(argv[2]) == 60) { 
        char * out = crypt(argv[1], argv[2]);

        int ok = 0;
        int i;
        for (i = 0; i < 60; i++) {
            if (out[i] != argv[2][i]) ok++;
        }
        printf("%d\n", ok);
        return ok;

            
    }
    
    if (argc == 3 && strlen(argv[2]) <= 2) {
        cost = atoi(argv[2]);
        if (cost < 4) cost = 4;
    }
    else if (argc != 2) {
        printf("Unknown argument 2\n");
        return 100;
    }
    
    char settings [60 + 1];
    int i;

    for (i = 0; i < 60; i++) {
        settings[i] = 'X';
    }

    sprintf(settings, "$2a$%02d$", cost);
    for (i = 0; i < 22; i+=2) {
        sprintf(&(settings[i + 7]), "%02x", abs(arc4random()%255));
    }

    for (i = 29; i < 60; i++) {
        settings[i] = '0';
    }
    settings[60] = '\0';
        
    char * out = crypt(argv[1], settings);
    printf("%s\n", out);
    
    
    return 0;
}


