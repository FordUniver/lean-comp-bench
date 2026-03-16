import Lake
open Lake DSL

package SortBench

@[default_target]
lean_exe sortbench where
  root := `Main
