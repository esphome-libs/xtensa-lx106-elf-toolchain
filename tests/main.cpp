// Entry point that uses every test function, so the link keeps them.
#include <cstddef>
#include <cstdint>

extern "C" {
uint64_t verify_div64(uint64_t a, uint64_t b);
int32_t verify_div32(int32_t a, int32_t b);
uint32_t verify_bits(uint32_t v);
float verify_float(float a, float b);
double verify_double(double a, int n);
int verify_switch(int v);
uint32_t verify_shift64(uint64_t v, unsigned s);
int verify_format(char *out, size_t len, int a, const char *s, float f);
long verify_parse(const char *s);
size_t verify_flash(char *out, size_t len);
int verify_compare(const void *a, const void *b, size_t n);
}

namespace verify {
int containers(int seed);
}

volatile int verify_input = 7;

int main() {
  int seed = verify_input;
  char buffer[64];
  long total = verify::containers(seed);
  total += static_cast<long>(verify_div64(static_cast<uint64_t>(seed) << 40, seed + 1));
  total += verify_div32(seed * 1000, seed + 2);
  total += verify_bits(seed);
  total += static_cast<long>(verify_float(seed, 2.0f));
  total += static_cast<long>(verify_double(seed, 3));
  total += verify_switch(seed);
  total += verify_shift64(seed, 9);
  total += verify_format(buffer, sizeof(buffer), seed, "text", 1.25f);
  total += verify_parse(buffer);
  total += verify_flash(buffer, sizeof(buffer));
  total += verify_compare(buffer, "stored", 6);
  return static_cast<int>(total);
}
