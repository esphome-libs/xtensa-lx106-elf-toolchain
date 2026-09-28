// libstdc++ templates and the C++ front end.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace verify {

class Base {
 public:
  virtual ~Base() = default;
  virtual int value() const = 0;
};

class Derived : public Base {
 public:
  explicit Derived(int v) : v_(v) {}
  int value() const override { return this->v_ * 3; }

 protected:
  int v_;
};

template<typename T, size_t N> T sum(const std::array<T, N> &items) {
  T total{};
  for (const auto &item : items)
    total += item;
  return total;
}

int containers(int seed) {
  std::vector<int> values;
  for (int i = 0; i < 16; i++)
    values.push_back((seed * 31 + i * 17) % 101);
  std::sort(values.begin(), values.end(), [](int a, int b) { return a > b; });
  std::string text = "v";
  for (int v : values)
    text += std::to_string(v);
  std::array<float, 4> floats{1.5f, 2.25f, static_cast<float>(seed), std::sqrt(static_cast<float>(seed + 1))};
  std::unique_ptr<Base> object = std::make_unique<Derived>(values.front());
  std::function<int(int)> fn = [&object](int x) { return object->value() + x; };
  return fn(static_cast<int>(text.size())) + static_cast<int>(sum(floats));
}

}  // namespace verify
