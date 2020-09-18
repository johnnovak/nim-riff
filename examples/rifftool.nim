import options
import os
import strformat
import strutils

import riff
import simple_parseopt


proc printChunks(infile: string) =
  var r = openRiffFile(infile)
  defer: r.close()

  for ci in r.walkChunks():
    echo " ".repeat((r.cursor.path.len-1) * 2), ci


proc printChunksRecursive(infile: string) =
  var r = openRiffFile(infile)
  defer: r.close()

  proc walkChunks(depth: Natural = 0) =
    let cc = r.currentChunk
    echo " ".repeat(depth*2), cc

    if cc.kind == ckGroup:
      if r.hasSubchunks:
        discard r.enterGroup()
        walkChunks(depth+1)
        r.exitGroup()
      else:
        echo " ".repeat((depth+1)*2), "<empty>"

    if r.hasNextChunk:
      discard r.nextChunk()
      walkChunks(depth)

  walkChunks()


proc recreateFile(infile, outfile: string) =
  var r = openRiffFile(infile)
  var w = createRiffFile(outfile, r.formTypeId, r.endian)
  defer:
    r.close()
    w.close()

  proc copyBytes(numBytes: Natural) =
    var buf: array[4096, byte]
    var bytesLeft = numBytes
    while bytesLeft > 0:
      let bytesToCopy = min(bytesLeft, buf.len)
      r.read(buf, 0, bytesToCopy)
      w.write(buf, 0, bytesToCopy)
      dec(bytesLeft, bytesToCopy)

  proc walkChunks(depth: Natural = 0) =
    let cc = r.currentChunk

    if cc.kind == ckGroup:
      w.beginListChunk(cc.formatTypeId)
      if r.hasSubchunks:
        discard r.enterGroup()
        walkChunks(depth+1)
        r.exitGroup()
      w.endChunk()
    else:
      w.beginChunk(cc.id)
      copyBytes(cc.size)
      w.endChunk()

    if r.hasNextChunk:
      discard r.nextChunk()
      walkChunks(depth)

  if r.hasSubchunks:
    discard r.enterGroup()
    walkChunks()

#[
proc extractChunk(infile, outfile: string, chunkId: string) =
  var r = openRiffFile(infile)
  var w = open(outfile, fmWrite)
  defer:
    w.close()
    r.close()

  proc findChunk(chunkId: string): Option[ChunkInfo] =
    while r.hasNextChunk():
      let ci = r.nextChunk()
      if ci.kind == ckGroup:
        r.enterGroup()
        let ci = findChunk(chunkId)
        if ci.isSome:
          return ci
      else:
        if ci.id == chunkId:
          return some(ci)
    r.exitGroup()
    return none(ChunkInfo)

  proc findChunk(chunkId: string): Option[ChunkInfo] =
    let cc = r.currentChunk
    echo " ".repeat(depth*2), cc

    if cc.kind == ckGroup:
      if r.hasSubchunks():
        discard r.enterGroup()
        walkChunks(depth+1)
        r.exitGroup()
      else:
        echo " ".repeat((depth+1)*2), "<empty>"

    if r.hasNextChunk():
      discard r.nextChunk()
      walkChunks(depth)


  let res = findChunk(chunkId)
  if res.isNone:
    quit fmt"Could not find chunk '{chunkId}' in input file"
  else:
    let ci = res.get

    proc copyBytes(numBytes: Natural) =
      var buf: array[4096, byte]
      var bytesLeft = numBytes
      while bytesLeft > 0:
        let bytesToCopy = min(bytesLeft, buf.len)
        r.read(buf, 0, bytesToCopy)
        if writeBuffer(w, buf[0].addr, bytesToCopy) != bytesToCopy:
          quit fmt"Error writing file '{outfile}'"
        dec(bytesLeft, bytesToCopy)

    copyBytes(ci.size)
]#

proc main() =
  simple_parseopt.command_name("rifftool")

  simple_parseopt.config:
    dash_dash_parameters.no_slash

  let (opts, supplied) = get_options_and_supplied:
    show          = false  {.alias("s"), info("show chunk tree").}
    showRecursive = false  {.alias("S"), info("show chunk tree (recursive)").}
    recreate      = false  {.alias("r"), info("recreate file").}

    extract:       string  {.alias("x"),
                            info("extract data from first chunk with this ID into a file").}

    infile:        string  {.bare, info("input file").}
    outfile:       string  {.bare, info("output file").}


  if opts.show:
    if not supplied.infile:
      quit "Input file must be specified"

    printChunks(opts.infile)

  elif opts.showRecursive:
    if not supplied.infile:
      quit "Input file must be specified"

    printChunksRecursive(opts.infile)

  elif opts.recreate:
    if not supplied.infile:
      quit "Input file must be specified"
    if not supplied.outfile:
      quit "Output file must be specified"

    recreateFile(opts.infile, opts.outfile)
#[
  elif supplied.extract:
    if not supplied.infile:
      quit "Input file must be specified"
    if not supplied.outfile:
      quit "Output file must be specified"

    let chunkId = opts.extract
    if not validFourCC(chunkID):
      quit fmt"Chunk ID '{chunkId}' specified to extract is not " &
           "a valid RIFF FourCC"

    extractChunk(opts.infile, opts.outfile, chunkId)
]#
  else:
    quit "Missing arguments, use -h for help"


main()

