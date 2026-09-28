/* libc calls, and the flash string helpers the compiler patches relate to. */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/pgmspace.h>

static const char verify_flash_text[] PROGMEM = "stored in flash";

int verify_format(char *out, size_t len, int a, const char *s, float f) {
  return snprintf(out, len, "%d:%s:%.2f:%08x", a, s, (double) f, (unsigned) a);
}

long verify_parse(const char *s) {
  while (isspace((unsigned char) *s))
    s++;
  return strtol(s, NULL, 0) + (isdigit((unsigned char) *s) ? 1 : 0);
}

size_t verify_flash(char *out, size_t len) {
  strncpy_P(out, verify_flash_text, len);
  return strlen_P(verify_flash_text) + pgm_read_byte(verify_flash_text) + pgm_read_dword(verify_flash_text);
}

int verify_compare(const void *a, const void *b, size_t n) { return memcmp(a, b, n) + (int) strlen((const char *) a); }
