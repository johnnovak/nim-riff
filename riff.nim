## :Author: John Novak <john@johnnovak.net>
##

import binstreams
import endians
import strformat
import strutils
import tables

export tables


# References
# ==========
#
# [1] "EA IFF 85" Standard for Interchange Format Files
# (Electronic Arts, 1985)
# https://wiki.amigaos.net/wiki/EA_IFF_85_Standard_for_Interchange_Format_Files
# http://www.martinreddy.net/gfx/2d/IFF.txt
#
# [2] A Quick Introduction to IFF
# (AmigaOS Documentation Wiki)
# https://wiki.amigaos.net/wiki/A_Quick_Introduction_to_IFF
#
# [3] Resource Interchange File Format
# (Wikipedia)
# https://en.wikipedia.org/wiki/Resource_Interchange_File_Format
#
# [4] RIFF (Resource Interchange File Format)
# (Digital Preservation. Library of Congress)
# https://www.loc.gov/preservation/digital/formats/fdd/fdd000025.shtml
#
# [5] Multimedia Programming Interface and Data Specifications 1.0
# (Microsoft / IBM, August 1991)
# http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/riffmci.pdf
#
# [6] Multimedia Data Standards Update
# (Microsoft, April 1994)
# http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/RIFFNEW.pdf
#
# [7] Exiftool - Riff Info Tags
# (ExifTool website)
# https://exiftool.org/TagNames/RIFF.html#Info
#
# [8] Exchangeable image file format for digital still cameras, Exif Version
# 2.32
# (Camera & Imaging Products Association, May 2019)
# http://www.cipa.jp/std/documents/e/DC-X008-Translation-2019-E.pdf
#
# [9] Audio Interchange File Format: "AIFF", Version 1.3
# (Apple, January 1989)
# http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf
#
# [10] AVI RIFF File Reference
# (Microsoft Dev Center, May 2018)
# https://docs.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference
#

# {{{ Common

const
  FourCCSize = 4
  ChunkHeaderSize = 8

const  # Top level chunk IDs
  FourCC_RIFF* = "RIFF"  ## RIFF chunk (little endian), may contain subchunks
  FourCC_RIFX* = "RIFX"  ## RIFX chunk (big endian), may contain subchunks

const  # RIFF form types
  FourCC_ACON* = "ACON"  ## Windows NT Animated Cursor
  FourCC_AVI*  = "AVI "  ## Audio Vide Interleave
  FourCC_BND*  = "BND "  ## Bundle File Format (file contains a series of
                         ## RIFF chunks)
  FourCC_DIB*  = "DIB "  ## Device Independent Bitmap File Format
  FourCC_RDIB  = "RDIB"  ## RIFF DIB File Format
  FourCC_MIDI* = "MIDI"  ## Musical Instrument Digital Interface File Format
  FourCC_RMID* = "RMID"  ## RIFF MIDI File Format
  FourCC_PAL*  = "PAL "  ## Palette File Format
  FourCC_RTF*  = "RTF "  ## Rich Text Format
  FourCC_WAVE* = "WAVE"  ## Waveform Audio File Format

let riffFormTypeNames = {
  FourCC_ACON: "Windows NT Animated Cursor Format",
  FourCC_AVI:  "Audio Vide Interleave Format",
  FourCC_BND:  "Bundle File Format Format",
  FourCC_DIB:  "Device Independent Bitmap File Format",
  FourCC_RDIB: "RIFF DIB File Format",
  FourCC_MIDI: "Musical Instrument Digital Interface File Format",
  FourCC_RMID: "RIFF MIDI File Format",
  FourCC_PAL:  "Palette File Format",
  FourCC_RTF:  "Rich Text Format",
  FourCC_WAVE: "Waveform Audio File Format"
}.toTable

const  # Standard RIFF chunks
  FourCC_LIST* = "LIST"  ## LIST chunk, may contain subchunks

  FourCC_DISP* = "DISP"  ## display chunk, contains easy to representation of
                         ## the data
  FourCC_JUNK* = "JUNK"  ## represents padding, filler or no relevant data

  FourCC_PAD*  = "PAD "  ## represents padding, filler or no relevant data (if
                         ## the pad chunk makes the next chunk align on a 2k
                         ## boundary, this padding must be preserved when
                         ## modifying the file)

  FourCC_INFO* = "INFO"  ## metadata about the file

  FourCC_CSET* = "CSET"  ## defines the character-set and language
                         ## used in the file (Latin-1 is assumed if not
                         ## specified)

  FourCC_CTOC* = "CTOC"  ## compound file table of contents
  FourCC_CGRP* = "CGRP"  ## compound file element group


# INFO subchunk types
const
  # From [5]
  FourCC_INFO_IARL* = "IARL"
  FourCC_INFO_IART* = "IART"
  FourCC_INFO_ICMS* = "ICMS"
  FourCC_INFO_ICMT* = "ICMT"
  FourCC_INFO_ICOP* = "ICOP"
  FourCC_INFO_ICRD* = "ICRD"
  FourCC_INFO_ICRP* = "ICRP"
  FourCC_INFO_IDIM* = "IDIM"
  FourCC_INFO_IDPI* = "IDPI"
  FourCC_INFO_IENG* = "IENG"
  FourCC_INFO_IGNR* = "IGNR"
  FourCC_INFO_IKEY* = "IKEY"
  FourCC_INFO_ILGT* = "ILGT"
  FourCC_INFO_IMED* = "IMED"
  FourCC_INFO_INAM* = "INAM"
  FourCC_INFO_IPLT* = "IPLT"
  FourCC_INFO_IPRD* = "IPRD"
  FourCC_INFO_ISBJ* = "ISBJ"
  FourCC_INFO_ISFT* = "ISFT"
  FourCC_INFO_ISHP* = "ISHP"
  FourCC_INFO_ISRC* = "ISRC"
  FourCC_INFO_ISRF* = "ISRF"
  FourCC_INFO_ITCH* = "ITCH"

  # From [7]
  FourCC_INFO_AGES* = "AGES"
  FourCC_INFO_CMNT* = "CMNT"
  FourCC_INFO_CODE* = "CODE"
  FourCC_INFO_COMM* = "COMM"
  FourCC_INFO_DIRC* = "DIRC"
  FourCC_INFO_DISP* = "DISP"
  FourCC_INFO_DTIM* = "DTIM"
  FourCC_INFO_GENR* = "GENR"
  FourCC_INFO_IAS1* = "IAS1"
  FourCC_INFO_IAS2* = "IAS2"
  FourCC_INFO_IAS3* = "IAS3"
  FourCC_INFO_IAS4* = "IAS4"
  FourCC_INFO_IAS5* = "IAS5"
  FourCC_INFO_IAS6* = "IAS6"
  FourCC_INFO_IAS7* = "IAS7"
  FourCC_INFO_IAS8* = "IAS8"
  FourCC_INFO_IAS9* = "IAS9"
  FourCC_INFO_IBSU* = "IBSU"
  FourCC_INFO_ICAS* = "ICAS"
  FourCC_INFO_ICDS* = "ICDS"
  FourCC_INFO_ICNM* = "ICNM"
  FourCC_INFO_ICNT* = "ICNT"
  FourCC_INFO_IDIT* = "IDIT"
  FourCC_INFO_IDST* = "IDST"
  FourCC_INFO_IEDT* = "IEDT"
  FourCC_INFO_IENC* = "IENC"
  FourCC_INFO_ILGU* = "ILGU"
  FourCC_INFO_ILIU* = "ILIU"
  FourCC_INFO_ILNG* = "ILNG"
  FourCC_INFO_IMBI* = "IMBI"
  FourCC_INFO_IMBU* = "IMBU"
  FourCC_INFO_IMIT* = "IMIT"
  FourCC_INFO_IMIU* = "IMIU"
  FourCC_INFO_IMUS* = "IMUS"
  FourCC_INFO_IPDS* = "IPDS"
  FourCC_INFO_IPRO* = "IPRO"
  FourCC_INFO_IRIP* = "IRIP"
  FourCC_INFO_IRTD* = "IRTD"
  FourCC_INFO_ISGN* = "ISGN"
  FourCC_INFO_ISMP* = "ISMP"
  FourCC_INFO_ISTD* = "ISTD"
  FourCC_INFO_ISTR* = "ISTR"
  FourCC_INFO_IWMU* = "IWMU"
  FourCC_INFO_IWRI* = "IWRI"
  FourCC_INFO_LANG* = "LANG"
  FourCC_INFO_LOCA* = "LOCA"
  FourCC_INFO_PRT1* = "PRT1"
  FourCC_INFO_PRT2* = "PRT2"
  FourCC_INFO_RATE* = "RATE"
  FourCC_INFO_STAR* = "STAR"
  FourCC_INFO_STAT* = "STAT"
  FourCC_INFO_TAPE* = "TAPE"
  FourCC_INFO_TCDO* = "TCDO"
  FourCC_INFO_TCOD* = "TCOD"
  FourCC_INFO_TITL* = "TITL"
  FourCC_INFO_TLEN* = "TLEN"
  FourCC_INFO_TORG* = "TORG"
  FourCC_INFO_TRCK* = "TRCK"
  FourCC_INFO_TURL* = "TURL"
  FourCC_INFO_TVER* = "TVER"
  FourCC_INFO_VMAJ* = "VMAJ"
  FourCC_INFO_VMIN* = "VMIN"
  FourCC_INFO_YEAR* = "YEAR"

let infoSubchunkNames* = {
  # From [5]
  FourCC_INFO_IARL: "Archival Location",
  FourCC_INFO_IART: "Artist",
  FourCC_INFO_ICMS: "Commissioned",
  FourCC_INFO_ICMT: "Comments",
  FourCC_INFO_ICOP: "Copyright",
  FourCC_INFO_ICRD: "Creation Date",
  FourCC_INFO_ICRP: "Cropped",
  FourCC_INFO_IDIM: "Dimensions",
  FourCC_INFO_IDPI: "Dots Per Inch",
  FourCC_INFO_IENG: "Engineer",
  FourCC_INFO_IGNR: "Genre",
  FourCC_INFO_IKEY: "Keywords",
  FourCC_INFO_ILGT: "Lightness",
  FourCC_INFO_IMED: "Medium",
  FourCC_INFO_INAM: "Name",
  FourCC_INFO_IPLT: "Palette Setting",
  FourCC_INFO_IPRD: "Product",
  FourCC_INFO_ISBJ: "Subject",
  FourCC_INFO_ISFT: "Software",
  FourCC_INFO_ISHP: "Sharpness",
  FourCC_INFO_ISRC: "Source",
  FourCC_INFO_ISRF: "Source Form",
  FourCC_INFO_ITCH: "Technician",

  # From [7]
  FourCC_INFO_AGES: "Rated",
  FourCC_INFO_CMNT: "Comment",
  FourCC_INFO_CODE: "Encoded By",
  FourCC_INFO_COMM: "Comments",
  FourCC_INFO_DIRC: "Directory",
  FourCC_INFO_DISP: "Sound Scheme Title",
  FourCC_INFO_DTIM: "Date Time Original",
  FourCC_INFO_GENR: "Genre",
  FourCC_INFO_IAS1: "First Language",
  FourCC_INFO_IAS2: "Second Language",
  FourCC_INFO_IAS3: "Third Language",
  FourCC_INFO_IAS4: "Fourth Language",
  FourCC_INFO_IAS5: "Fifth Language",
  FourCC_INFO_IAS6: "Sixth Language",
  FourCC_INFO_IAS7: "Seventh Language",
  FourCC_INFO_IAS8: "Eighth Language",
  FourCC_INFO_IAS9: "Ninth Language",
  FourCC_INFO_IBSU: "Base URL",
  FourCC_INFO_ICAS: "Default Audio Stream",
  FourCC_INFO_ICDS: "Costume Designer",
  FourCC_INFO_ICMS: "Commissioned",
  FourCC_INFO_ICMT: "Comment",
  FourCC_INFO_ICNM: "Cinematographer",
  FourCC_INFO_ICNT: "Country",
  FourCC_INFO_IDIT: "Date Time Original",
  FourCC_INFO_IDST: "Distributed By",
  FourCC_INFO_IEDT: "Edited By",
  FourCC_INFO_IENC: "Encoded By",
  FourCC_INFO_ILGU: "Logo URL",
  FourCC_INFO_ILIU: "Logo Icon URL",
  FourCC_INFO_ILNG: "Language",
  FourCC_INFO_IMBI: "More Info Banner Image",
  FourCC_INFO_IMBU: "More Info Banner URL",
  FourCC_INFO_IMIT: "More Info Text",
  FourCC_INFO_IMIU: "More Info URL",
  FourCC_INFO_IMUS: "Music By",
  FourCC_INFO_IPDS: "Production Designer",
  FourCC_INFO_IPRO: "Produced By",
  FourCC_INFO_IRIP: "Ripped By",
  FourCC_INFO_IRTD: "Rating",
  FourCC_INFO_ISGN: "Secondary Genre",
  FourCC_INFO_ISMP: "Time Code",
  FourCC_INFO_ISTD: "Production Studio",
  FourCC_INFO_ISTR: "Starring",
  FourCC_INFO_IWMU: "Watermark URL",
  FourCC_INFO_IWRI: "Written By",
  FourCC_INFO_LANG: "Language",
  FourCC_INFO_LOCA: "Location",
  FourCC_INFO_PRT1: "Part",
  FourCC_INFO_PRT2: "Number Of Parts",
  FourCC_INFO_RATE: "Rate",
  FourCC_INFO_STAR: "Starring",
  FourCC_INFO_STAT: "Statistics",
  FourCC_INFO_TAPE: "Tape Name",
  FourCC_INFO_TCDO: "End Timecode",
  FourCC_INFO_TCOD: "Start Timecode",
  FourCC_INFO_TITL: "Title",
  FourCC_INFO_TLEN: "Length (ms)",
  FourCC_INFO_TORG: "Organization",
  FourCC_INFO_TRCK: "Track Number",
  FourCC_INFO_TURL: "URL",
  FourCC_INFO_TVER: "Version",
  FourCC_INFO_VMAJ: "Vegas Version Major",
  FourCC_INFO_VMIN: "Vegas Version Minor",
  FourCC_INFO_YEAR: "Year"
}.toTable


type
  ChunkKind* = enum
    ckChunk, ckGroup

  ChunkInfo* = object
    ## contains information about a chunk
    id*:      string  ## 4-char chunk ID
    size*:    uint32  ## number of data bytes the chunk contains (not including the
                      ## optional pad byte if the number of data bytes is odd)
    filePos*: int64   ## file position of the chunk data (absolute position in
                      ## bytes from the start of the file)

    case kind*: ChunkKind
    of ckGroup: formatType*: string
    of ckChunk: discard


proc validFourCC(fourCC: string, relaxed: bool = false): bool =
  if fourCC.len != 4: return false
  var spaceFound = false
  for i in 0..3:
    if spaceFound:
      if fourCC[i] != ' ': return false
    elif fourCC[i] == ' ': spaceFound = true
    elif not relaxed and not fourCC[i].isAlphaNumeric: return false
    # TODO for IFF: 32-126, format types only alphanumeric
  return true


# }}}
# {{{ Reader

type 
  Cursor* = object
    path: seq[ChunkInfo]

func initCursor(c: var Cursor) =
  c.path = newSeq[ChunkInfo]()

func atRootChunk(c: Cursor): bool =
  c.path.len == 1

func currChunk(c: Cursor): ChunkInfo =
  c.path[^1]

func parentChunk(c: Cursor): ChunkInfo =
  if c.atRootChunk(): c.path[0] else: c.path[^2]

proc down(c: var Cursor, ci: ChunkInfo) =
  c.path.add(ci)

proc up(c: var Cursor) =
  discard c.path.pop()

proc replaceCurrent(c: var Cursor, ci: ChunkInfo) =
  discard c.path.pop()
  c.path.add(ci)


type
  RiffReader* = ref object
    fs:                 FileStream
    cursor:             Cursor
    doEnterGroup:       bool
    doCheckChunkLimits: bool

  RiffReaderError* = object of Exception

using rr: RiffReader


func filename*(rr): string = rr.fs.filename
func endian*(rr): Endianness = rr.fs.endian

func currChunk*(rr): ChunkInfo = rr.cursor.currChunk

func cursor*(rr): Cursor = deepCopy(rr.cursor)

func `cursor=`*(rr; c: Cursor) =
  rr.cursor = c
  rr.doEnterGroup = false


proc checkChunkLimits(rr; numBytes: Natural) =
  if not rr.doCheckChunkLimits: return
  let
    pc = rr.cursor.parentChunk
    chunkPos = rr.fs.getPosition() - (pc.filePos + ChunkHeaderSize)

  if chunkPos + numBytes > pc.size.int64:
    raise newException(RiffReaderError,
      "Cannot read past the end of the current group chunk, " &
      fmt"chunk size: {pc.size}, chunk pos: {chunkPos}, " &
      fmt"bytes to read: {numBytes}")

proc read(rr; T: typedesc[SomeNumber]): T =
  let numBytes = sizeof(T)
  checkChunkLimits(rr, numBytes)
  result = rr.fs.read(T)

proc read[T: SomeNumber](rr; buf: var openArray[T],
                         startIndex, numValues: Natural) =
  let numBytes = numValues * sizeof(T)
  checkChunkLimits(rr, numBytes)
  rr.fs.read(buf, startIndex, numValues)

proc readStr(rr; length: Natural): string =
  let numBytes = length
  checkChunkLimits(rr, numBytes)
  result = rr.fs.readStr(length)

proc readFourCC*(rr): string =
  rr.readStr(4)

func roundToEven(n: SomeInteger): SomeInteger =
  if n mod 2 == 1: n+1 else: n


proc hasNextChunk*(rr): bool =
  if rr.doEnterGroup:
    return rr.cursor.currChunk.size > FourCCSize
  else:
    let
      pc = rr.cursor.parentChunk
      cc = rr.cursor.currChunk
      parentEndPos = pc.filePos + ChunkHeaderSize + pc.size.int64
      currEndPos = cc.filePos + ChunkHeaderSize + roundToEven(cc.size.int64)

    return currEndPos < parentEndPos


proc nextChunk*(rr): ChunkInfo =
  if not rr.hasNextChunk:
    raise newException(RiffReaderError,
      "Cannot go to next chunk: " &
      "there are no more chunks in the current group")

  let cc = rr.cursor.currChunk
  let nextPos = if rr.doEnterGroup:
    cc.filePos + ChunkHeaderSize + FourCCSize
  else:
    cc.filePos + ChunkHeaderSize + roundToEven(cc.size.int64)

  rr.fs.setPosition(nextPos)

  let chunkId = rr.readFourCC()
  if not validFourCC(chunkId):
    # TODO print fourCC by char
    raise newException(RiffReaderError, fmt"Invalid chunk ID: {chunkId}")

  var ci = if chunkId == FourCC_LIST:
    ChunkInfo(kind: ckGroup)
  else:
    ChunkInfo(kind: ckChunk)

  ci.id = chunkId
  ci.size = rr.read(uint32)
  ci.filePos = nextPos

  if ci.kind == ckGroup:
    ci.formatType = rr.readFourCC()
    if not validFourCC(ci.formatType):
      raise newException(RiffReaderError,
        fmt"Invalid format type ID: {ci.formatType}")  # TODO print fourCC by char

  if rr.doEnterGroup:
    rr.cursor.down(ci)
    rr.doEnterGroup = false
  else:
    rr.cursor.replaceCurrent(ci)

  result = ci


proc enterGroup*(rr) =
  rr.doEnterGroup = true

proc exitGroup*(rr) =
  if rr.cursor.atRootChunk:
    raise newException(RiffReaderError, "Cannot exit root chunk")

  elif rr.cursor.parentChunk.kind == ckGroup:
    rr.cursor.up()
  else:
    raise newException(RiffReaderError,
      fmt"Cannot exit non-group chunk '{rr.cursor.currChunk.id}'")


proc readFormChunkHeader(rr): ChunkInfo =
  var ci = ChunkInfo(kind: ckGroup)
  ci.id = rr.readFourCC()

  case ci.id:
  of FourCC_RIFF: rr.fs.endian = littleEndian
  of FourCC_RIFX: rr.fs.endian = bigEndian
  else:
    raise newException(RiffReaderError, fmt"Unknown root chunk ID: {ci.id}")

  ci.size = rr.read(uint32)  # TODO int32 for IFF
  ci.filePos = 0
  ci.formatType = rr.readFourCC()

  if not validFourCC(ci.formatType):
    raise newException(RiffReaderError,
      fmt"Invalid format type ID: {ci.formatType}")  # TODO print fourCC by char

  result = ci


# TODO file variant, bufsize
proc openRiffFile*(filename: string, bufSize: int = -1): RiffReader =
  var rr = new RiffReader
  rr.fs = openFileStream(filename, littleEndian)

  rr.doCheckChunkLimits = false
  let ci = rr.readFormChunkHeader()
  initCursor(rr.cursor)
  rr.cursor.down(ci)
  rr.doCheckChunkLimits = true
  result = rr


proc close*(rr) = rr.fs.close()

#[
proc setChunkPos*(rr; pos: int64, mode: FileSeekPos = fspSet) =
  let chunkSize = rr.currChunk.size.int64
  var newPos: int64
  case mode
  of fspSet: newPos = pos
  of fspCur: newPos = rr.chunkPos + pos
  of fspEnd: newPos = chunkSize - pos

  if newPos < 0 or newPos > chunkSize-1:
    raise newException(RiffReaderError,
                       "Cannot seek past the current chunk's bounds")

  rr.fs.setPosition(rr.currChunk.dataPos + ChunkHeaderSize + newPos)
  rr.chunkPos = newPos
]#



# }}}
# {{{ Writer

#[
type
  RiffWriter* = object
    # private
    chunkSize:      seq[int64]
    chunkSizePos:   seq[int64]
    trackChunkSize: bool

  RiffWriterError* = object of Exception

proc initRiffWriter*(): RiffWriter =

func filename*(ww: RiffWriter): string {.inline.} =
  ww.writer.filename

func endianness*(ww: RiffWriter): Endianness {.inline.} =
  ww.writer.endianness

proc checkFileClosed(ww: var RiffWriter) =
  if ww.writer.file == nil:
    raise newException(RiffWriterError, "File closed")

proc incChunkSize(ww: var RiffWriter, numBytes: Natural) =
  if ww.trackChunkSize and ww.chunkSize.len > 0:
    inc(ww.chunkSize[ww.chunkSize.high], numBytes)

template writeInternal(ww: var RiffWriter, numBytes: Natural, write: untyped) =
  checkFileClosed(ww)
  write
  incChunkSize(ww, numBytes)

# TODO wrap binstreams write procs

proc writeFourCC*(ww: var RiffWriter, fourCC: string) =
  ww.writeInternal(4, ww.writer.writeString(fourCC, 4))


proc startChunk*(ww: var RiffWriter, id: string) =
  ww.checkFileClosed()

  ww.trackChunkSize = false

  ww.writeFourCC(id)
  ww.chunkSizePos.add(getFilePos(ww.writer.file))
  ww.writeUInt32(0)  # endChunk() will update this with the correct value
  ww.chunkSize.add(0)

  ww.trackChunkSize = true


proc endChunk*(ww: var RiffWriter) =
  ww.checkFileClosed()

  ww.trackChunkSize = false

  var chunkSize = ww.chunkSize.pop()
  if chunkSize mod 2 > 0:
    ww.writeInt8(0)  # padding byte (chunks must contain even number of bytes)
  setFilePos(ww.writer.file, ww.chunkSizePos.pop())
  ww.writeUInt32(chunkSize.uint32)
  setFilePos(ww.writer.file, 0, fspEnd)

  # Add real (potentially padded) chunk size to the parent chunk size
  if ww.chunkSize.len > 0:
    if chunkSize mod 2 > 0:
      inc(chunkSize)
    ww.chunkSize[ww.chunkSize.high] += chunkSize + ChunkHeaderSize

  ww.trackChunkSize = true


proc writeRiffFile*(filename: string, bufSize: Natural = 4096,
                    endianness = littleEndian): RiffWriter =
  var ww = initRiffWriter()

  ww.writer = createFile(filename, bufSize, endianness)

  ww.chunkSize = newSeq[int64]()
  ww.chunkSizePos = newSeq[int64]()
  ww.trackChunkSize = false

  case ww.writer.endianness:
  of littleEndian: ww.startChunk(FourCC_RIFF_LE)
  of bigEndian:    ww.startChunk(FourCC_RIFF_BE)

  result = ww


proc close*(ww: var RiffWriter) =
  ww.checkFileClosed()
  ww.endChunk()
  ww.writer.close()
]#
# }}}

# vim: et:ts=2:sw=2:fdm=marker
