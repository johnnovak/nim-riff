import sequtils, os, unittest

import riff


# {{{ Test data file creation
const TestFileLE = "testfileLE"
const TestFileBE = "testfileBE"
const TestFormTypeID = "test"

proc createTestFile(filename: string, endian: Endianness) =
  # Create a test RIFF file with the following structure:
  #
  # "RIFF"        - root RIFF chunk ('test' format type ID)
  #   "G1  "      - LIST (empty, no subchunks)
  #   "INFO"      - LIST
  #     "ICOP"    - info tag
  #     "IART"    - info tag
  #     "ICMT"    - info tag
  #   "G2  "      - LIST
  #     "emp1"    - empty
  #     "num "    - numeric value read tests
  #     "G21 "    - LIST
  #       "str "  - string tests
  #   "JUNK"      - filler
  #   "G3  "
  #     "buf "    - buffered read tests
  #
  var w = createRiffFile(filename, TestFormTypeId, endian)

  #-----------------------------------------
  # "G1  "
  w.beginListChunk("G1  ")
  w.endChunk()

  # "INFO"
  w.beginListChunk(FourCC_INFO)
  w.beginChunk(FourCC_INFO_ICOP)
  w.writeZStr("(C) John Novak 2020")
  w.endChunk()
  w.beginChunk(FourCC_INFO_IART)
  w.writeZStr("John Novak")
  w.endChunk()
  w.beginChunk(FourCC_INFO_ICMT)
  w.writeZStr("just some comment")
  w.endChunk()
  w.endChunk()

  #-----------------------------------------
  # "G2  "
  w.beginListChunk("G2  ")

  w.beginChunk("emp1")
  w.endChunk()

  w.beginChunk("num ")
  w.write(234'u8)
  w.write(-42'i8)
  w.write(12345'u16)
  w.write(-8765'i16)
  w.write(0xdeadbeef'u32)
  w.write(0xcafebabe'i32)
  w.write(0xdeadbeefcafebabe'u64)
  w.write(0xcafebabedeadbeef'i64)
  w.write(1234.5678'f32)
  w.write(987654.7654321234'f64)
  w.write(7'i8) # to make the chunk size odd
  w.endChunk()

  # "G21 "
  w.beginListChunk("G21 ")

  w.beginChunk("str ")
  w.writeChar('x')
  w.writeStr("Ḽơᶉëᶆ ȋṕšᶙṁ ḍỡḽǭᵳ ʂǐť")
  w.writeBStr("árvíztűrőtükörfúrógép")
  w.writeWStr("WStr")
  w.writeZStr("ZStr")
  w.writeBZStr("BZstr")
  w.writeWZStr("WZstr")
  w.writeFourCC("ILBM")
  w.endChunk()

  w.endChunk()  # "G21 "
  w.endChunk()  # "G2  "

  #-----------------------------------------
  # "JUNK"
  w.beginChunk(FourCC_JUNK)
  var junk: array[1000, byte]
  w.write(junk, 0, junk.len)
  w.endChunk

  #-----------------------------------------
  # "G3  "
  w.beginListChunk("G3  ")

  var buf: array[10_000, float32]
  var f = 0'f32
  for i in 0..buf.high:
    buf[i] = f
    f += 0.123

  w.beginChunk("buf ")
  w.write(buf, 0, buf.len)
  w.write(buf, 1000, 4096)
  w.write(buf, 0, 0)
  w.write(buf, 0, 1)
  w.write(buf, 10, 10)
  w.endChunk()

  w.endChunk()  # "G3  "

  w.endChunk()


createTestFile(TestFileLE, littleEndian)
createTestFile(TestFileBE, bigEndian)

# }}}

suite "Helpers":
  test "validFourCC() - strict":
    check validFourCC("RIFF")
    check validFourCC("lst ")
    check validFourCC("hDR1")
    check validFourCC("1234")
    check validFourCC("    ")

    check not validFourCC("")
    check not validFourCC(" ")
    check not validFourCC("RIFF ")
    check not validFourCC("A BC")
    check not validFourCC(" ABC")
    check not validFourCC("MOD!")
    check not validFourCC("$hdr")
    check not validFourCC("XM-1")

  test "validFourCC() - relaxed":
    check validFourCC("MOD!", relaxed=true)
    check validFourCC("$hdr", relaxed=true)
    check validFourCC("XM-1", relaxed=true)

  test "fourCCToCharStr()":
    check fourCCToCharStr("RIFF") == "('R', 'I', 'F', 'F')"
    check fourCCToCharStr("A#\27 ") == "('A', '#', '\\27', ' ')"

#[
proc filename*(rr): string =
proc endian*(rr): Endianness =
proc formTypeId*(rr): string =
proc currentChunk*(rr): ChunkInfo =
proc cursor*(rr): Cursor =
proc `cursor=`*(rr; c: Cursor) =
proc getChunkPos*(rr): uint32 =
proc getFilePos*(rr): int64 =
proc setChunkPos*(rr; pos: uint32, relativeTo: ChunkSeekPos = cspSet) =
proc read*(rr; T: typedesc[SomeNumber]): T =
proc read*[T: SomeNumber](rr; buf: var openArray[T],
                          startIndex, numValues: Natural) =
proc readChar*(rr): char =
proc readStr*(rr; length: Natural): string =
proc readBStr*(rr): string =
proc readWStr*(rr): string =
proc readZStr*(rr): string =
proc readBZStr*(rr): string =
proc readWZStr*(rr): string =
proc readFourCC*(rr): string =
proc hasNextChunk*(rr): bool =
proc nextChunk*(rr): ChunkInfo =
proc enterGroup*(rr) =
proc exitGroup*(rr) =
proc openRiffFile*(filename: string, bufSize: int = -1): RiffReader =
proc close*(rr) =
]#


# {{{ WaveReader
suite "WaveReader":

  # {{{ create reader from filename - LE
  test "create reader from filename - LE":
    var r = openRiffFile(TestFileLE)
    check r.filename == TestFileLE
    check r.endian == littleEndian
    check r.formTypeId == TestFormTypeID

    let ci = r.currentChunk()
    check ci.id == FourCC_RIFF
    check ci.size == 57762
    check ci.filePos == 0
    check ci.kind == ckGroup
    check ci.formatTypeId == TestFormTypeID

    r.close()

  # }}}
  # {{{ create reader from filename - BE
  test "create reader from filename - BE":
    var r = openRiffFile(TestFileBE)
    check r.filename == TestFileBE
    check r.endian == bigEndian
    check r.formTypeId == TestFormTypeID

    let ci = r.currentChunk()
    check ci.id == FourCC_RIFX
    check ci.size == 57762
    check ci.filePos == 0
    check ci.kind == ckGroup
    check ci.formatTypeId == TestFormTypeID

    r.close()

  # }}}
  # {{{ create reader file handle - LE
  test "create reader file handle - LE":
    var f = open(TestFileLE)
    var r = openRiffFile(f)
    check r.filename == ""
    check r.endian == littleEndian
    check r.formTypeId == TestFormTypeID

    let ci = r.currentChunk()
    check ci.id == FourCC_RIFF
    check ci.size == 57762
    check ci.filePos == 0
    check ci.kind == ckGroup
    check ci.formatTypeId == TestFormTypeID

    r.close()

  # }}}
  # {{{ create reader file handle - BE
  test "create reader file handle - BE":
    var f = open(TestFileBE)
    var r = openRiffFile(f)
    check r.filename == ""
    check r.endian == bigEndian
    check r.formTypeId == TestFormTypeID

    let ci = r.currentChunk()
    check ci.id == FourCC_RIFX
    check ci.size == 57762
    check ci.filePos == 0
    check ci.kind == ckGroup
    check ci.formatTypeId == TestFormTypeID

    r.close()

  # }}}
  # {{{ iterate through all top-level chunks
  template iterateTopLevelChunks(fname: string) =
    var r = openRiffFile(fname)

    check r.hasSubchunks()
    var ci = r.enterGroup()
    check ci.id == FourCC_LIST
    check ci.size == 4
    check ci.filePos == 12
    check ci.kind == ckGroup
    check ci.formatTypeId == "G1  "

    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == FourCC_LIST
    check ci.size == 78
    check ci.filePos == 24
    check ci.kind == ckGroup
    check ci.formatTypeId == "INFO"

    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == FourCC_LIST
    check ci.size == 196
    check ci.filePos == 110
    check ci.kind == ckGroup
    check ci.formatTypeId == "G2  "

    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == "JUNK"
    check ci.size == 1000
    check ci.filePos == 314
    check ci.kind == ckChunk

    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == FourCC_LIST
    check ci.size == 56440
    check ci.filePos == 1322
    check ci.kind == ckGroup
    check ci.formatTypeId == "G3  "

    check not r.hasNextChunk()

    r.close()


  test "iterate through all top-level chunks (LE)":
    iterateTopLevelChunks(TestFileLE)

  test "iterate through all top-level chunks (BE)":
    iterateTopLevelChunks(TestFileBE)

  # }}}
  # {{{ iterate through all chunks
  template iterateAllChunks(fname: string) =
    var r = openRiffFile(fname)
    var ci: ChunkInfo

    block: # G1
      check r.hasSubchunks()
      ci = r.enterGroup()
      check ci.id == FourCC_LIST
      check ci.formatTypeId == "G1  "

      check not r.hasSubchunks()

    block: # INFO
      check r.hasNextChunk()
      ci = r.nextChunk()
      check ci.id == FourCC_LIST
      check ci.formatTypeId == "INFO"

      check r.hasSubchunks()
      ci = r.enterGroup()
      check ci.id == "ICOP"

      check r.hasNextChunk()
      ci = r.nextChunk()
      check ci.id == "IART"

      check r.hasNextChunk()
      ci = r.nextChunk()
      check ci.id == "ICMT"

      check not r.hasNextChunk()
      r.exitGroup()

    block: # G2
      ci = r.nextChunk()
      check ci.id == FourCC_LIST
      check ci.formatTypeId == "G2  "

      check r.hasSubchunks()
      ci = r.enterGroup()
      check ci.id == "emp1"

      check r.hasNextChunk()
      ci = r.nextChunk()
      check ci.id == "num "

      block: # G21
        check r.hasNextChunk()
        ci = r.nextChunk()
        check ci.id == FourCC_List
        check ci.formatTypeId == "G21 "

        check r.hasSubchunks()
        ci = r.enterGroup()
        check ci.id == "str "

        check not r.hasNextChunk()
        r.exitGroup()

      r.exitGroup()

    # JUNK
    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == "JUNK"

    block: # G3
      check r.hasNextChunk()
      ci = r.nextChunk()
      check ci.id == FourCC_LIST
      check ci.formatTypeId == "G3  "

      check not r.hasNextChunk()

      check r.hasSubchunks()
      ci = r.enterGroup()
      check ci.id == "buf "

      check not r.hasNextChunk()
      r.exitGroup()

    check not r.hasNextChunk()
    r.close()


  test "iterate through all chunks - LE":
    iterateAllChunks(TestFileLE)

  test "iterate through all chunks - BE":
    iterateAllChunks(TestFileBE)

  # }}}
  # {{{ enter/exit empty group chunk
  template enterExistEmptyGroupChunk(fname: string) =
    var r = openRiffFile(fname)
    var ci: ChunkInfo

    check r.hasSubchunks()
    ci = r.enterGroup()
    check ci.id == FourCC_LIST
    check ci.formatTypeId == "G1  "

    check not r.hasSubchunks()

    check r.hasNextChunk()
    ci = r.nextChunk()
    check ci.id == FourCC_LIST
    check ci.formatTypeId == "INFO"

  test "enter/exit empty group chunk - LE":
    enterExistEmptyGroupChunk(TestFileLE)

  test "enter/exit empty group chunk - BE":
    enterExistEmptyGroupChunk(TestFileBE)

  # }}}
  # {{{ walkChunk() - all chunks
  template walkChunkAll(fname, formId: string) =
    var r = openRiffFile(fname)

    var cur = toSeq(r.walkChunks)

    check cur.len == 14

    check cur[0].id == formId
    check cur[0].kind == ckGroup
    check cur[0].formatTypeId == TestFormTypeID

    check cur[1].kind == ckGroup
    check cur[1].formatTypeId == "G1  "

    check cur[2].kind == ckGroup
    check cur[2].formatTypeId == FourCC_INFO

    check cur[3].id == FourCC_INFO_ICOP
    check cur[4].id == FourCC_INFO_IART
    check cur[5].id == FourCC_INFO_ICMT

    check cur[6].kind == ckGroup
    check cur[6].formatTypeId == "G2  "

    check cur[7].id == "emp1"
    check cur[8].id == "num "

    check cur[9].kind == ckGroup
    check cur[9].formatTypeId == "G21 "

    check cur[10].id == "str "

    check cur[11].id == "JUNK"

    check cur[12].kind == ckGroup
    check cur[12].formatTypeId == "G3  "

    check cur[13].id == "buf "

    r.close()


  test "walkChunk() - all chunks - LE":
    walkChunkAll(TestFileLE, FourCC_RIFF)

  test "walkChunk() - all chunks - BE":
    walkChunkAll(TestFileBE, FourCC_RIFX)

  # }}}
  # {{{ walkChunk() - subtrees
  template walkChunkSubtrees(fname: string) =
    var r = openRiffFile(fname)

    var ci = r.enterGroup()
    check ci.formatTypeId == "G1  "
    var cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.formatTypeId == "G1  "
    check cur.len == 1
    check cur[0].formatTypeId == "G1  "

    ci = r.nextChunk()
    check ci.formatTypeId == FourCC_INFO
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.formatTypeId == FourCC_INFO
    check cur.len == 4
    check cur[0].formatTypeId == "INFO"
    check cur[1].id == FourCC_INFO_ICOP
    check cur[2].id == FourCC_INFO_IART
    check cur[3].id == FourCC_INFO_ICMT

    ci = r.enterGroup()
    check ci.id == FourCC_INFO_ICOP
    cur = toSeq(r.walkChunks)
    check cur.len == 3
    check cur[0].id == FourCC_INFO_ICOP
    check cur[1].id == FourCC_INFO_IART
    check cur[2].id == FourCC_INFO_ICMT

    r.exitGroup()
    ci = r.nextChunk()
    check ci.formatTypeId == "G2  "
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.formatTypeId == "G2  "
    check cur.len == 5
    check cur[0].formatTypeId == "G2  "
    check cur[1].id == "emp1"
    check cur[2].id == "num "
    check cur[3].formatTypeId == "G21 "
    check cur[4].id == "str "

    ci = r.nextChunk()
    check ci.id == FourCC_JUNK
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.id == FourCC_JUNK
    check cur.len == 3
    check cur[0].id == FourCC_JUNK
    check cur[1].formatTypeId == "G3  "
    check cur[2].id == "buf "

    ci = r.nextChunk()
    check ci.formatTypeId == "G3  "
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.formatTypeId == "G3  "
    check cur.len == 2
    check cur[0].formatTypeId == "G3  "
    check cur[1].id == "buf "

    ci = r.enterGroup()
    check ci.id == "buf "
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    check ci.id == "buf "
    check cur.len == 1
    check cur[0].id == "buf "

    r.close()

  test "walkChunk() - subtrees - LE":
    walkChunkSubtrees(TestFileLE)

  test "walkChunk() - subtrees - BE":
    walkChunkSubtrees(TestFileBE)

# }}}

  # {{{ ERRORS - operations on a closed reader
  test "ERRORS - operations on a closed reader":
    var r = openRiffFile(TestFileLE)
    r.close()

    expect RiffReadError: discard r.filename
    expect RiffReadError: discard r.endian
    expect RiffReadError: discard r.formTypeId
    expect RiffReadError: discard r.currentChunk
    expect RiffReadError: discard r.cursor
    expect RiffReadError: discard r.getChunkPos()
    expect RiffReadError: discard r.getFilePos()
    expect RiffReadError: r.setChunkPos(1)
    expect RiffReadError: discard r.read(uint8)
    expect RiffReadError: discard r.readChar()
    expect RiffReadError: discard r.readStr(1)
    expect RiffReadError: discard r.readBStr()
    expect RiffReadError: discard r.readWStr()
    expect RiffReadError: discard r.readZStr()
    expect RiffReadError: discard r.readBZStr()
    expect RiffReadError: discard r.readWZStr()
    expect RiffReadError: discard r.readFourCC()
    expect RiffReadError: discard r.hasNextChunk()
    expect RiffReadError: discard r.nextChunk()
    expect RiffReadError: discard r.enterGroup()
    expect RiffReadError: r.exitGroup()
    expect RiffReadError: r.close()

  # }}}
  # {{{ ERRORS - navigating chunks
  test "ERRORS - navigating chunks":
    var r = openRiffFile(TestFileLE)

    # exiting root chunk
    var ci = r.currentChunk
    check ci.formatTypeId == TestFormTypeId
    expect RiffReadError: r.exitGroup()

    # entering empty group chunk
    ci = r.enterGroup()
    check ci.formatTypeId == "G1  "
    expect RiffReadError: discard r.enterGroup()

    # entering regular chunk
    ci = r.nextChunk()
    ci = r.enterGroup()
    check ci.id == FourCC_INFO_ICOP
    expect RiffReadError: discard r.enterGroup()

    # iterating past last subchunk
    ci = r.currentChunk
    check ci.id == FourCC_INFO_ICOP
    ci = r.nextChunk()
    ci = r.nextChunk()
    check ci.id == FourCC_INFO_ICMT
    expect RiffReadError: discard r.nextChunk()

  # }}}

# vim: et:ts=2:sw=2:fdm=marker
