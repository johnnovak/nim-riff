import os
import strutils

import riff

if paramCount() == 0:
  echo "Usage: printchunks FILE"
  quit()

var infile = paramStr(1)
var rr = openRiffFile(infile)

proc walkChunks(depth: Natural = 1) =
  while rr.hasNextChunk():
    let ci = rr.nextChunk()
    echo " ".repeat(depth*2), ci
    if ci.kind == ckGroup:
      rr.enterGroup()
      walkChunks(depth+1)
  rr.exitGroup()

echo rr.currChunk
rr.enterGroup()
walkChunks()

rr.close()

