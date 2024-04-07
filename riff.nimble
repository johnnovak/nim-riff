# Package

version       = "0.2.2"
author        = "John Novak <john@johnnovak.net>"
description   = "RIFF file handling in Nim"
license       = "WTFPL"

skipDirs = @["doc", "examples", "tests"]

# Dependencies

requires "nim >= 2.0.2", "binstreams >= 0.2.0"

# Tasks

task tests, "Run all tests":
  exec "nim c -r tests/tests"

task examples, "Compiles the examples":
  exec "nim c -d:release examples/rifftool.nim"

task examplesDebug, "Compiles the examples (debug mode)":
  exec "nim c examples/rifftool.nim"

task docgen, "Generate HTML documentation":
  exec "nim doc -o:doc/riff.html riff"
