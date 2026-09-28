/* Integer and floating point code paths, including the helpers libgcc provides. */
#include <math.h>
#include <stdint.h>

uint64_t verify_div64(uint64_t a, uint64_t b) { return b ? a / b + a % b : 0; }

int32_t verify_div32(int32_t a, int32_t b) { return b ? a / b - a % b : 0; }

uint32_t verify_bits(uint32_t v) {
  v = __builtin_bswap32(v);
  v ^= (v << 13) | (v >> 19);
  return v + (uint32_t) __builtin_popcount(v) + (uint32_t) __builtin_clz(v | 1);
}

float verify_float(float a, float b) { return sqrtf(a * a + b * b) / (b + 1.5f); }

double verify_double(double a, int n) { return pow(a, n) + fmod(a, 3.0) + (double) n / 7.0; }

/* Dense enough to become a jump table */
int verify_switch(int v) {
  switch (v) {
    case 0:
      return 11;
    case 1:
      return 23;
    case 2:
      return 5;
    case 3:
      return 47;
    case 4:
      return 2;
    case 5:
      return 91;
    case 6:
      return 13;
    case 7:
      return 8;
    default:
      return -1;
  }
}

uint32_t verify_shift64(uint64_t v, unsigned s) { return (uint32_t) ((v << s) ^ (v >> (64 - s))); }
