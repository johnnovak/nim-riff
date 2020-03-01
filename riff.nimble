# Package

version       = "0.1.0"
author        = "John Novak <john@johnnovak.net>"
description   = "RIFF file handling in Nim"
license       = "WTFPL"

skipDirs = @["doc", "examples"]

# Dependencies

requires "nim >= 1.0.6"

# Tasks

#task examples, "Compiles the examples":
#  exec "nim c -d:release examples/readtest.nim"

#task examplesDebug, "Compiles the examples (debug mode)":
#  exec "nim c examples/readtest.nim"

task docgen, "Generate HTML documentation":
  exec "nim doc -o:doc/riff.html riff"
