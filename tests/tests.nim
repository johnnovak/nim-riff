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
#createTestFile(TestFileBE, bigEndian)

# }}}

suite "Helpers":
  test "validFourCC - strict":
    assert validFourCC("RIFF")
    assert validFourCC("lst ")
    assert validFourCC("hDR1")
    assert validFourCC("1234")
    assert validFourCC("    ")

    assert not validFourCC("")
    assert not validFourCC(" ")
    assert not validFourCC("RIFF ")
    assert not validFourCC("A BC")
    assert not validFourCC(" ABC")
    assert not validFourCC("MOD!")
    assert not validFourCC("$hdr")
    assert not validFourCC("XM-1")

  test "validFourCC - relaxed":
    assert validFourCC("MOD!", relaxed=true)
    assert validFourCC("$hdr", relaxed=true)
    assert validFourCC("XM-1", relaxed=true)

  test "fourCCToCharStr":
    assert fourCCToCharStr("RIFF") == "('R', 'I', 'F', 'F')"
    assert fourCCToCharStr("A#\27 ") == "('A', '#', '\\27', ' ')"

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

  # {{{ open a file using a filename
  test "open a file using a filename":
    var r = openRiffFile(TestFileLE)
    assert r.filename == TestFileLE
    assert r.endian == littleEndian
    assert r.formTypeId == TestFormTypeID

    let ci = r.currentChunk()
    assert ci.id == FourCC_RIFF
    assert ci.size == 57762
    assert ci.filePos == 0
    assert ci.kind == ckGroup
    assert ci.formatTypeId == TestFormTypeID

    r.close()

  # }}}
  # {{{ iterate through all top-level chunks
  test "iterate through all top-level chunks":
    var r = openRiffFile(TestFileLE)

    var ci = r.currentChunk
    assert ci.id == FourCC_RIFF
    assert ci.size == 57762
    assert ci.filePos == 0
    assert ci.kind == ckGroup
    assert ci.formatTypeId == TestFormTypeID

    assert r.hasSubchunks()
    ci = r.enterGroup()
    assert ci.id == FourCC_LIST
    assert ci.size == 4
    assert ci.filePos == 12
    assert ci.kind == ckGroup
    assert ci.formatTypeId == "G1  "

    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == FourCC_LIST
    assert ci.size == 78
    assert ci.filePos == 24
    assert ci.kind == ckGroup
    assert ci.formatTypeId == "INFO"

    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == FourCC_LIST
    assert ci.size == 196
    assert ci.filePos == 110
    assert ci.kind == ckGroup
    assert ci.formatTypeId == "G2  "

    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == "JUNK"
    assert ci.size == 1000
    assert ci.filePos == 314
    assert ci.kind == ckChunk

    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == FourCC_LIST
    assert ci.size == 56440
    assert ci.filePos == 1322
    assert ci.kind == ckGroup
    assert ci.formatTypeId == "G3  "

    assert not r.hasNextChunk()

    r.close()

  # }}}
  # {{{ enter/exist empty LIST chunks
  test "enter/exit empty LIST chunks":
    var r = openRiffFile(TestFileLE)
    var ci: ChunkInfo

    assert r.hasSubchunks()
    ci = r.enterGroup()
    assert ci.id == FourCC_LIST
    assert ci.formatTypeId == "G1  "

    assert not r.hasSubchunks()

    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == FourCC_LIST
    assert ci.formatTypeId == "INFO"

  # }}}
  # {{{ iterate through all chunks
  test "iterate through all chunks":
    var r = openRiffFile(TestFileLE)

    var ci = r.currentChunk
    assert ci.id == FourCC_RIFF
    assert ci.size == 57762
    assert ci.filePos == 0
    assert ci.kind == ckGroup
    assert ci.formatTypeId == TestFormTypeID

    block: # G1
      assert r.hasSubchunks()
      ci = r.enterGroup()
      assert ci.id == FourCC_LIST
      assert ci.formatTypeId == "G1  "

      assert not r.hasSubchunks()

    block: # INFO
      assert r.hasNextChunk()
      ci = r.nextChunk()
      assert ci.id == FourCC_LIST
      assert ci.formatTypeId == "INFO"

      assert r.hasSubchunks()
      ci = r.enterGroup()
      assert ci.id == "ICOP"

      assert r.hasNextChunk()
      ci = r.nextChunk()
      assert ci.id == "IART"

      assert r.hasNextChunk()
      ci = r.nextChunk()
      assert ci.id == "ICMT"

      assert not r.hasNextChunk()
      r.exitGroup()

    block: # G2
      ci = r.nextChunk()
      assert ci.id == FourCC_LIST
      assert ci.formatTypeId == "G2  "

      assert r.hasSubchunks()
      ci = r.enterGroup()
      assert ci.id == "emp1"

      assert r.hasNextChunk()
      ci = r.nextChunk()
      assert ci.id == "num "

      block: # G21
        assert r.hasNextChunk()
        ci = r.nextChunk()
        assert ci.id == FourCC_List
        assert ci.formatTypeId == "G21 "

        assert r.hasSubchunks()
        ci = r.enterGroup()
        assert ci.id == "str "

        assert not r.hasNextChunk()
        r.exitGroup()

      r.exitGroup()

    # JUNK
    assert r.hasNextChunk()
    ci = r.nextChunk()
    assert ci.id == "JUNK"

    block: # G3
      assert r.hasNextChunk()
      ci = r.nextChunk()
      assert ci.id == FourCC_LIST
      assert ci.formatTypeId == "G3  "

      assert not r.hasNextChunk()

      assert r.hasSubchunks()
      ci = r.enterGroup()
      assert ci.id == "buf "

      assert not r.hasNextChunk()
      r.exitGroup()

    assert not r.hasNextChunk()
    r.close()

  # }}}
  # {{{ walkChunk() - all chunks
  test "walkChunk() - all chunks":
    var r = openRiffFile(TestFileLE)

    var cur = toSeq(r.walkChunks)

    assert cur.len == 14

    assert cur[0].last.id == FourCC_RIFF
    assert cur[0].last.kind == ckGroup
    assert cur[0].last.formatTypeId == TestFormTypeID

    assert cur[1].last.kind == ckGroup
    assert cur[1].last.formatTypeId == "G1  "

    assert cur[2].last.kind == ckGroup
    assert cur[2].last.formatTypeId == FourCC_INFO

    assert cur[3].last.id == FourCC_INFO_ICOP
    assert cur[4].last.id == FourCC_INFO_IART
    assert cur[5].last.id == FourCC_INFO_ICMT

    assert cur[6].last.kind == ckGroup
    assert cur[6].last.formatTypeId == "G2  "

    assert cur[7].last.id == "emp1"
    assert cur[8].last.id == "num "

    assert cur[9].last.kind == ckGroup
    assert cur[9].last.formatTypeId == "G21 "

    assert cur[10].last.id == "str "

    assert cur[11].last.id == "JUNK"

    assert cur[12].last.kind == ckGroup
    assert cur[12].last.formatTypeId == "G3  "

    assert cur[13].last.id == "buf "

    r.close()

  # }}}
  # {{{ walkChunk() - subtrees
  test "walkChunk() - subtrees":
    var r = openRiffFile(TestFileLE)

    var ci = r.enterGroup()
    assert ci.formatTypeId == "G1  "
    var cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    assert ci.formatTypeId == "G1  "
    assert cur.len == 1
    assert cur[0].last.formatTypeId == "G1  "

    ci = r.nextChunk()
    assert ci.formatTypeId == FourCC_INFO
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    assert ci.formatTypeId == FourCC_INFO
    assert cur.len == 4
    assert cur[0].last.formatTypeId == "INFO"
    assert cur[1].last.id == FourCC_INFO_ICOP
    assert cur[2].last.id == FourCC_INFO_IART
    assert cur[3].last.id == FourCC_INFO_ICMT

    ci = r.nextChunk()
    assert ci.formatTypeId == "G2  "
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    assert ci.formatTypeId == "G2  "
    assert cur.len == 5
    assert cur[0].last.formatTypeId == "G2  "
    assert cur[1].last.id == "emp1"
    assert cur[2].last.id == "num "
    assert cur[3].last.formatTypeId == "G21 "
    assert cur[4].last.id == "str "

    ci = r.nextChunk()
    assert ci.id == FourCC_JUNK
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    assert ci.id == FourCC_JUNK
    assert cur.len == 3
    assert cur[0].last.id == FourCC_JUNK
    assert cur[1].last.formatTypeId == "G3  "
    assert cur[2].last.id == "buf "

    ci = r.nextChunk()
    assert ci.formatTypeId == "G3  "
    cur = toSeq(r.walkChunks)
    ci = r.currentChunk
    assert ci.formatTypeId == "G3  "
    assert cur.len == 2
    assert cur[0].last.formatTypeId == "G3  "
    assert cur[1].last.id == "buf "

    r.close()
# }}}

# vim: et:ts=2:sw=2:fdm=marker
