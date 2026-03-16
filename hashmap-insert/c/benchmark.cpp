// Reproducing lacker/lean4perf benchmark
// 10M string->int insertions into a hash map
#include <iostream>
#include <string>
#include <unordered_map>
#include <chrono>

int main() {
  auto t0 = std::chrono::steady_clock::now();

  std::unordered_map<std::string, int> map;
  for (int i = 0; i < 10000000; i++) {
    map[std::to_string(i)] = i;
  }

  auto t1 = std::chrono::steady_clock::now();
  double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

  std::cout << "ran " << map.size() << " map inserts in " << ms << "ms" << std::endl;
  return 0;
}
