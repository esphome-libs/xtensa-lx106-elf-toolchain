// Compiled once with pch.h precompiled and once without; both must match.
#include "pch.h"

int pch_user(int seed) {
  std::vector<int> values(8, seed);
  std::string text = std::to_string(std::accumulate(values.begin(), values.end(), 0));
  return static_cast<int>(text.size()) + static_cast<int>(std::sqrt(static_cast<float>(seed)));
}
