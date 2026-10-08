// Section attributes inside templates must reach the instantiation (GCC PR70435).
template<typename T> struct Table {
  static const T *get() {
    static const T values[] __attribute__((section(".irom.text.template_data"))) = {1, 2, 3};
    return values;
  }
};

template<typename T> __attribute__((noinline, section(".iram.text.template_func"))) T twice(T value) { return value * 2; }

const int *use_table() { return Table<int>::get(); }
int use_func(int value) { return twice(value); }

// Static data member of a class template (the non-local branch).
template<typename T> struct Member {
  static const T values[3];
};
template<typename T> const T Member<T>::values[3] __attribute__((section(".irom.text.template_member"))) = {4, 5, 6};

const int *use_member() { return Member<int>::values; }
