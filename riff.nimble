# Package

version       = "0.1.0"
author        = "John Novak <john@johnnovak.net>"
description   = "RIFF file handling in Nim"
license       = "WTFPL"

skipDirs = @["doc", "examples"]

# Dependencies

requires "nim >= 1.4.8", "binstreams"

# Tasks

task tests, "Run all tests":
  exec "nim c -r tests/tests"

task examples, "Compiles the examples":
  exec "nim c -d:release examples/rifftool.nim"

task examplesDebug, "Compiles the examples (debug mode)":
  exec "nim c examples/rifftool.nim"

task docgen, "Generate HTML documentation":
  exec "nim doc -o:doc/riff.html riff"
