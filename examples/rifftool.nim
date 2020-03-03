import os
import strutils

import riff
import simple_parseopt


simple_parseopt.command_name("rifftool")

simple_parseopt.config:
  dash_dash_parameters.no_slash

let (opts, supplied) = get_options_and_supplied:
  show         = false {.alias("s"), info("show chunk tree").}
  recreate     = false {.alias("r"), info("recreate file").}
  extract      = false {.alias("x"), info("extract chunk into file").}
  bigEndian    = false {.alias("b"), info("force big-endian output").}
  littleEndian = false {.alias("L"), info("force little-endian output").}
  infile:      string  {.bare, info("input file").}
  outfile:     string  {.bare, info("output file").}


proc printChunks(infile: string) =
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
  walkChunks()
  rr.close()


proc recreateFile(infile, outfile: string) =
  var r = openRiffFile(infile)
  var w = createRiffFile(outfile, r.formTypeId, r.endian)

  proc copyBytes(numBytes: Natural) =
    var buf: array[4096, byte]
    var bytesLeft = numBytes
    while bytesLeft > 0:
      let bytesToCopy = min(bytesLeft, buf.len)
      r.read(buf, 0, bytesToCopy)
      w.write(buf, 0, bytesToCopy)
      dec(bytesLeft, bytesToCopy)

  proc walkChunks() =
    while r.hasNextChunk():
      let ci = r.nextChunk()
      if ci.kind == ckGroup:
        w.beginListChunk(ci.formatTypeId)
        r.enterGroup()
        walkChunks()
      else:
        w.beginChunk(ci.id)
        copyBytes(ci.size)
        w.endChunk()
    r.exitGroup()
    w.endChunk()

  walkChunks()
  r.close()


if opts.show:
  if not supplied.infile:
    quit "Input file must be specified"
  printChunks(opts.infile)

elif opts.recreate:
  if not supplied.infile:
    quit "Input file must be specified"
  if not supplied.outfile:
    quit "Output file must be specified"
  if supplied.bigEndian and supplied.littleEndian:
    quit "Ambiguous options: both force big endian and little endian have been specified"
  recreateFile(opts.infile, opts.outfile)

else:
  quit "Missing arguments, use -h for help"

