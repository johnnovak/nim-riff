## :Author: John Novak <john@johnnovak.net>
##
## **nim-riff** is a library for reading and writing [Resource Interchange File
## Format (RIFF)](https://en.wikipedia.org/wiki/Resource_Interchange_File_Format)
## files.
##
## Main features:
## * Reading/writing of little-endian (`RIFF`) and big-endian (`RIFX`) RIFF
##   files
## * Strict adherence to the RIFF standard
## * Convenient helper methods to navigate the chunk hierarchy
## * Cursor support
##
## Please refer to the guide on how to use the library.
##

import binstreams
import strformat
import strutils
import tables


# {{{ References
# ==============
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
# }}}

# {{{ Common

const
  FourCCSize* = 4
  ChunkHeaderSize* = 8
  MinListChunkSize = 4
  ChunkSizePlaceholder = 0xffffffff'u32

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

let riffFormTypeNames* = {
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

  FourCC_CTOC* = "CTOC"  ## compound file table of contents (unsupported)
  FourCC_CGRP* = "CGRP"  ## compound file element group (unsupported)


# {{{ INFO subchunk types
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
# }}}

type
  ChunkKind* = enum
    ckChunk, ckGroup

  ChunkInfo* = object
    ## contains information about a chunk
    id*:      string  ## 4-char chunk ID (FourCC)

    size*:    uint32  ## chunk data length in bytes (NOT including the
                      ## optional pad byte if data length is odd)

    filePos*: int64   ## absolute position in bytes from the start of the file

    case kind*: ChunkKind   ## ckGroup - group chunks,
                            ## ckChunk - normal subchunks
    of ckGroup: formatTypeId*: string  ## format type FourCC for group chunks
    of ckChunk: discard

  Cursor* = object  ## a location in the RIFF file (a chunk path plus a chunk offset)
    path*:     seq[ChunkInfo]
    chunkPos*: uint32
    filePos*:  int64


proc validFourCC*(fourCC: string, relaxed: bool = false): bool =
  ## Returns true is the passed in FourCC is valid. A FourCC is valid if:
  ## * it is 4 ASCII characters long
  ## * it only contains alphanumeric ASCII characters or spaces
  ## * spaces are only allowed in trailing position
  ##
  ## If the `relaxed` flag is set to true, all ASCII characters are allowed
  ## (but the trailing spaces only rule still applies).
  ##
  if fourCC.len != 4: return false
  var spaceFound = false
  for c in fourCC:
    if spaceFound:
      if c != ' ': return false
    elif c == ' ': spaceFound = true
    elif not relaxed and not c.isAlphaNumeric: return false
  return true

proc fourCCToCharStr*(fourCC: string): string =
  ## Converts a FourCC to a printable string.
  ## ```
  ## fourCCToCharStr("RIFF")     # returns "('R', 'I', 'F', 'F')"
  ## fourCCToCharStr("A#\27 ")   # returns "('A', '#', '\\27', ' ')"
  ## ```
  result = "("
  for i in 0..3:
    let c = fourCC[i]
    if c < ' ': result &= fmt"'\{c.ord}'"
    else: result &= fmt"'{c}'"
    if i < 3: result &= ", "
  result &= ")"

# }}}
# {{{ Reader

type
  RiffReader* = ref object  ## a RIFF file opened for reading
    fs:                 FileStream
    path:               seq[ChunkInfo]
    currParentChunk:    ChunkInfo
    doCheckChunkLimits: bool
    doCheckNotInGroup:  bool
    closed:             bool

  RiffReadError* = object of IOError

  ChunkSeekPos* = enum  ## cspSet - from the start of the chunk
                        ## cspCur - from the current position
                        ## cspEnd - from the end of the chunk
    cspSet, cspCur, cspEnd

using rr: RiffReader


func atRootChunk(rr): bool =
  rr.path.len == 1

template currChunk(rr): ChunkInfo = rr.path[^1]

func parentChunk(rr): ChunkInfo =
  if rr.atRootChunk: rr.path[0] else: rr.path[^2]

proc cursorPop(rr): ChunkInfo =
  result = rr.path.pop()
  rr.currParentChunk = rr.parentChunk

proc cursorAdd(rr; ci: ChunkInfo) =
  rr.path.add(ci)
  rr.currParentChunk = rr.parentChunk

proc checkNotClosed(rr) =
  if rr.closed:
    raise newException(RiffReadError, "Reader has been closed")

type ReadOperation = enum
  roReadingData = (0, "Reading data"),
  roSetChunkPos = (1, "Setting chunk position")

proc checkNotInGroupChunk(rr; op: ReadOperation) =
  if rr.doCheckNotInGroup:
    if rr.currChunk.kind == ckGroup:
      raise newException(RiffReadError,
        fmt"{op} is not allowed in a group chunk")

proc filename*(rr): string =
  ## Returns the filename of the RIFF file.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  rr.checkNotClosed()
  rr.fs.filename

proc endian*(rr): Endianness =
  ## Returns the endianness of the RIFF file.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  rr.checkNotClosed()
  rr.fs.endian

proc formTypeId*(rr): string =
  ## Returns the form type ID of the RIFF file (this indicates the concrete
  ## format of the file, e.g. "WAVE" or "AVI ").
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  rr.checkNotClosed()
  rr.path[0].formatTypeId

proc currentChunk*(rr): ChunkInfo =
  ## Returns information about the current chunk.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  rr.checkNotClosed()
  rr.currChunk


proc checkChunkLimits(rr: RiffReader, numBytes: Natural) {.inline.} =
  if not rr.doCheckChunkLimits: return
  let
    pc = rr.currParentChunk
    chunkPos = rr.fs.getPosition() - (pc.filePos + ChunkHeaderSize)

  if chunkPos + numBytes > pc.size.int64:
    raise newException(RiffReadError,
      "Cannot read past the end of the current group chunk, " &
      fmt"chunk size: {pc.size}, chunk pos: {chunkPos}, " &
      fmt"bytes to read: {numBytes}")


proc getChunkPos*(rr): uint32 =
  ## Returns the current chunk position. The start of the chunk data
  ## (the first byte after the chunk headers) is the zero position.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  result = (rr.fs.getPosition() - rr.currChunk.filePos - ChunkHeaderSize).uint32
  if rr.currChunk.kind == ckGroup:
    dec(result, FourCCSize)


proc setChunkPos*(rr; pos: int64, relativeTo: ChunkSeekPos = cspSet) =
  ## Sets the current chunk position according to the `relativeTo` parameter.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  let ci = rr.currChunk
  let currChunkPos = rr.getChunkPos().int64

  var newPos = case relativeTo
  of cspSet: pos
  of cspCur: currChunkPos + pos
  of cspEnd: ci.size.int64 + pos

  if newPos < 0 or newPos >= ci.size.int64:
    raise newException(RiffReadError,
      "Cannot seek past the bounds of the current chunk, " &
      fmt"chunk size: {ci.size}, current chunk pos: {currChunkPos}, " &
      fmt"new chunk pos: {newPos}")

  rr.fs.setPosition(ci.filePos + ChunkHeaderSize + newPos)


proc getFilePos*(rr): int64 =
  ## Returns the current absolute file position.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.fs.getPosition()


proc cursor*(rr): Cursor =
  ## Returns a cursor that points the current chunk and chunk offset.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  Cursor(
    path: deepCopy(rr.path),
    filePos: rr.fs.getPosition(),
    chunkPos: rr.getChunkPos()
  )

proc `cursor=`*(rr; c: Cursor) =
  ## Restores the current chunk and chunk offset from a cursor.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.path = deepCopy(c.path)
  rr.currParentChunk = rr.parentChunk
  rr.fs.setPosition(c.filePos)


proc read*(rr; T: typedesc[SomeNumber]): T =
  ## Reads a numeric value; the type needs to be passed in as an argument.
  ##
  ## ```
  ## let i8 = r.read(uint8)
  ## let f32 = r.read(float32)
  ## let i64 = r.read(int64)
  ## ```
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.checkNotInGroupChunk(roReadingData)

  let numBytes = sizeof(T)
  checkChunkLimits(rr, numBytes)
  result = rr.fs.read(T)

proc read*[T: SomeNumber](rr; buf: var openArray[T],
                          startIndex, numValues: Natural) =
  ## Reads `numValues` number of values into `buf` starting from `startIndex`.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.checkNotInGroupChunk(roReadingData)

  let numBytes = numValues * sizeof(T)
  checkChunkLimits(rr, numBytes)
  rr.fs.read(buf, startIndex, numValues)

proc readChar*(rr): char =
  ## Reads a char.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.checkNotInGroupChunk(roReadingData)

  checkChunkLimits(rr, 1)
  result = rr.fs.readChar()

proc readStr*(rr; length: Natural): string =
  ## Reads `length` number of bytes as an UTF-8 string.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  rr.checkNotInGroupChunk(roReadingData)

  checkChunkLimits(rr, length)
  result = rr.fs.readStr(length)

proc readBStr*(rr): string =
  ## Reads a Pascal-style string (one `length` leading byte followed by
  ## `length` bytes of character data).
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  let length = rr.read(uint8)
  result = rr.readStr(length)

proc readWStr*(rr): string =
  ## Reads a Pascal-style string (one `length` leading word (16-bit int)
  ## followed by `length` bytes of character data).
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  let length = rr.read(uint16)
  result = rr.readStr(length)

proc readZStr*(rr): string =
  ## Read a C-style null-terminated string.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  result = ""
  while true:
    let c = rr.readChar()
    if c == chr(0): return
    result &= c

proc readBZStr*(rr): string =
  ## Reads a Pascal-style string (one `length` leading byte followed by
  ## `length` bytes of character data), that is also null-terminated.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  result = rr.readBStr()
  rr.setChunkPos(1, cspCur)

proc readWZStr*(rr): string =
  ## Reads a Pascal-style string (one `length` leading word (16-bit int)
  ## followed by `length` bytes of character data), that is also
  ## null-terminated.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  result = rr.readWStr()
  rr.setChunkPos(1, cspCur)

proc readFourCC*(rr): string =
  ## Reads the next 4-bytes as a FourCC string. It does not validate the
  ## FourCC.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised, or
  ## if an attempt has been made to read past the end of the chunk.
  ##
  ## Raises an `IOError` on read errors.
  rr.readStr(4)

func padToEven(n: SomeInteger): SomeInteger =
  if n mod 2 == 1: n+1 else: n


proc hasNextChunk*(rr): bool =
  ## Returns true if there are more sibling subchunks under the current parent
  ## group chunk.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  rr.checkNotClosed()
  let
    pc = rr.parentChunk
    cc = rr.currChunk
    parentEndPos = pc.filePos + ChunkHeaderSize + pc.size.int64
    currEndPos = cc.filePos + ChunkHeaderSize + padToEven(cc.size.int64)

  return currEndPos < parentEndPos


proc hasSubchunks*(rr): bool =
  return rr.currChunk.kind == ckGroup and
         rr.currChunk.size.int > MinListChunkSize

proc readChunk(rr; nextPos: int64): ChunkInfo =
  try:
    rr.doCheckNotInGroup = false

    let chunkId = rr.readFourCC()
    if not validFourCC(chunkId):
      raise newException(RiffReadError,
        fmt"Invalid chunk ID: {fourCCToCharStr(chunkId)}")

    var ci = if chunkId == FourCC_LIST:
      ChunkInfo(kind: ckGroup)
    else:
      ChunkInfo(kind: ckChunk)

    ci.id = chunkId
    ci.size = rr.read(uint32)
    # TODO check against filesize & remaining filesize
    ci.filePos = nextPos

    if ci.kind == ckGroup:
      ci.formatTypeId = rr.readFourCC()
      if not validFourCC(ci.formatTypeId):
        raise newException(RiffReadError,
          fmt"Invalid format type ID: {fourCCToCharStr(ci.formatTypeId)}")

    result = ci

  except: raise
  finally:
    rr.doCheckNotInGroup = true


proc nextChunk*(rr): ChunkInfo =
  ## Moves the current chunk pointer to the next sibling subchunk of the
  ## current parent group chunk, and sets the chunk offset to zero.
  ##
  ## Raises a `RiffReadError` if we're at the last subchunk of the current
  ## group chunk, or if an invalid FourCC has been encountered, or if the
  ## reader is closed or not initialised.
  ##
  ## Raises an `IOError` on read errors.
  rr.checkNotClosed()
  if not rr.hasNextChunk:
    raise newException(RiffReadError,
      "Cannot go to next chunk: " &
      "there are no more subchunks in the current group chunk")

  let cc = rr.currChunk
  let nextPos = cc.filePos + ChunkHeaderSize + padToEven(cc.size.int64)
  rr.fs.setPosition(nextPos)

  let ci = rr.readChunk(nextPos)

  discard rr.cursorPop()
  rr.cursorAdd(ci)
  result = ci


proc enterGroup*(rr): ChunkInfo =
  ##
  ## Raises a `RiffReadError` if the current chunk is not a group chunk, or if
  ## the reader is closed or not initialised.
  rr.checkNotClosed()

  if not rr.hasSubchunks:
    raise newException(RiffReadError,
      "Cannot enter group chunk: current chunk is not a group chunk, " &
      fmt"chunkId: {fourCCToCharStr(rr.currChunk.id)}")

  elif not rr.hasSubchunks:
    raise newException(RiffReadError,
      "Cannot enter group chunk: " &
      "there are no more subchunks in the current group chunk")

  let nextPos = rr.currChunk.filePos + ChunkHeaderSize + FourCCSize
  rr.fs.setPosition(nextPos)

  let ci = rr.readChunk(nextPos)

  rr.cursorAdd(ci)

  result = ci


proc exitGroup*(rr) =
  ## Sets the current chunk to the parent group chunk.
  ##
  ## Raises a `RiffReadError` if we're at the root level RIFF group chunk, or
  ## if the reader is closed or not initialised.
  rr.checkNotClosed()

  if rr.atRootChunk:
    raise newException(RiffReadError, "Cannot exit root chunk")
  elif rr.parentChunk.kind == ckGroup:
    discard rr.cursorPop()
  else:
    # This error indicates a bug, it should never happen
    raise newException(RiffReadError,
      fmt"Cannot exit non-group chunk '{rr.currChunk.id}'")


# TODO ignore/allow lists
iterator walkChunks*(rr): ChunkInfo {.closure.} =
  let startCur = rr.cursor()
  let startDepth = rr.path.len
  var ci = rr.currentChunk
  yield ci

  if ci.kind == ckChunk or
     ci.kind == ckGroup and rr.hasSubchunks:
    block main:
      while true:
        if ci.kind == ckGroup and rr.hasSubchunks:
          ci = rr.enterGroup()
          yield ci
        else:
          block next:
            if rr.hasNextChunk:
              ci = rr.nextChunk()
              yield ci
            else:
              if rr.path.len == startDepth: break main
              else:
                rr.exitGroup()
                if rr.path.len == startDepth: break main
                break next

  rr.cursor = startCur


proc readFormChunkHeader(rr): ChunkInfo =
  var ci = ChunkInfo(kind: ckGroup)
  ci.id = rr.readFourCC()

  case ci.id:
  of FourCC_RIFF: rr.fs.endian = littleEndian
  of FourCC_RIFX: rr.fs.endian = bigEndian
  else:
    raise newException(RiffReadError,
      fmt"Unknown root chunk ID: {fourCCToCharStr(ci.id)}")

  ci.size = rr.read(uint32)
  # TODO check against filesize
  ci.filePos = 0
  ci.formatTypeId = rr.readFourCC()

  if not validFourCC(ci.formatTypeId):
    raise newException(RiffReadError,
      fmt"Invalid format type ID: {fourCCToCharStr(ci.formatTypeId)}")

  result = ci


proc init(rr) =
  rr.doCheckChunkLimits = false
  let ci = rr.readFormChunkHeader()
  rr.path = newSeq[ChunkInfo]()
  rr.cursorAdd(ci)
  rr.doCheckChunkLimits = true
  rr.doCheckNotInGroup = true

proc openRiffFile*(filename: string, bufSize: int = -1): RiffReader =
  ## Opens a RIFF file specified by `filename`. Optionally overrides the
  ## default `bufSize` of the underlying binary stream reader. The endianness
  ## of the file is determined from the RIFF headers.
  ##
  ## Raises a `RiffReadError` if the file is not a valid RIFF file.
  ##
  ## Raises an `IOError` if the file cannot be opened.
  var rr = new RiffReader
  rr.fs = openFileStream(filename, littleEndian, fmRead, bufSize)
  rr.init()
  result = rr

proc openRiffFile*(f: File, bufSize: int = -1): RiffReader =
  ## Opens a RIFF file from an existing file handle. Optionally overrides the
  ## default `bufSize` of the underlying binary stream reader. The endianness
  ## of the file is determined from the RIFF headers.
  ##
  ## Raises a `RiffReadError` if the file is not a valid RIFF file.
  ##
  ## Raises an `IOError` if the file cannot be opened.
  var rr = new RiffReader
  rr.fs = newFileStream(f, littleEndian)
  rr.init()
  result = rr

proc close*(rr) =
  ## Closes the RIFF file.
  ##
  ## Raises a `RiffReadError` if the reader is closed or not initialised.
  ##
  ## Raises an `IOError` if the file cannot be closed.
  rr.checkNotClosed()
  rr.fs.close()
  rr.fs = nil
  rr.closed = true

# }}}
# {{{ Writer

type
  RiffWriter* = ref object
    fs:             FileStream
    path:           seq[ChunkInfo]
    trackChunkSize: bool
    inGroupChunk:   bool
    closed:         bool

  RiffWriteError* = object of IOError

using rw: RiffWriter


proc checkNotClosed(rw) =
  if rw.closed:
    raise newException(RiffWriteError, "Writer has been closed")

func filename*(rw): string =
  ## Returns the name of the file associated with the reader. If the
  ## reader was initialised from a file handle, the filename will be an
  ## empty string.
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  rw.checkNotClosed()
  rw.fs.filename

func endian*(rw): Endianness =
  ## Returns the endianness of the RIFF file associated with the reader.
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  rw.checkNotClosed()
  rw.fs.endian

proc incChunkSize(rw; numBytes: Natural) =
  if rw.trackChunkSize:
    inc(rw.path[^1].size, numBytes)

proc write*[T: SomeNumber](rw; value: T) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  checkNotClosed(rw)
  rw.fs.write(value)
  incChunkSize(rw, sizeof(T))

proc write*[T: SomeNumber](rw; buf: var openArray[T],
                           startIndex, numValues: Natural) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  checkNotClosed(rw)
  rw.fs.write(buf, startIndex, numValues)
  incChunkSize(rw, numValues * sizeof(T))

proc writeChar*(rw; c: char) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  checkNotClosed(rw)
  rw.fs.writeChar(c)
  incChunkSize(rw, 1)

proc writeStr*(rw; s: string) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  checkNotClosed(rw)
  rw.fs.writeStr(s)
  incChunkSize(rw, s.len)

proc writeBStr*(rw; s: string) =
  let length = min(s.len, uint8.high.int).uint8
  rw.write(length)
  var ss = s
  setLen(ss, length)
  rw.writeStr(ss)

proc writeWStr*(rw; s: string) =
  let length = min(s.len, uint16.high.int).uint16
  rw.write(length)
  var ss = s
  setLen(ss, length)
  rw.writeStr(ss)

proc writeZStr*(rw; s: string) =
  rw.writeStr(s)
  rw.write(0'u8)

proc writeBZStr*(rw; s: string) =
  rw.writeBStr(s)
  rw.write(0'u8)

proc writeWZStr*(rw; s: string) =
  rw.writeWStr(s)
  rw.write(0'u8)

proc writeFourCC*(rw; fourCC: string) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  assert fourCC.len == 4
  checkNotClosed(rw)
  var s = fourCC
  s.setLen(4)
  rw.fs.writeStr(s)
  incChunkSize(rw, 4)


proc doBeginChunk(rw; id: string) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  rw.checkNotClosed()
  rw.trackChunkSize = false

  rw.path.add(
    ChunkInfo(id: id, size: 0, filePos: rw.fs.getPosition())
  )

  rw.writeFourCC(id)
  rw.write(ChunkSizePlaceholder)  # endChunk() will update this

  rw.trackChunkSize = true


proc beginChunk*(rw; chunkId: string) =
  if not rw.inGroupChunk:
    raise newException(RiffWriteError,
      "Only RIFF, RIFX and LIST group chunks can contain subchunks")

  if not validFourCC(chunkId):
    raise newException(RiffReadError,
      fmt"Invalid chunk ID: {fourCCToCharStr(chunkId)}")

  if chunkId == FourCC_RIFF or chunkId == FourCC_RIFX or
     chunkId == FourCC_LIST:
    raise newException(RiffWriteError,
      "Regular chunks cannot have this ID: {chunkId}")

  rw.doBeginChunk(chunkId)
  rw.inGroupChunk = false


proc beginListChunk*(rw; formatTypeId: string) =
  if not rw.inGroupChunk:
    raise newException(RiffWriteError,
      "Only RIFF, RIFX and LIST group chunks can contain subchunks")

  if not validFourCC(formatTypeId):
    raise newException(RiffReadError,
      fmt"Invalid format type ID: {fourCCToCharStr(formatTypeId)}")

  rw.doBeginChunk(FourCC_LIST)
  rw.writeFourCC(formatTypeId)
  rw.inGroupChunk = true


proc endChunk*(rw) =
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  rw.checkNotClosed()
  rw.trackChunkSize = false

  var currChunk = rw.path.pop()
  # Write pad byte if chunk size is odd
  if currChunk.size mod 2 > 0: rw.write(0'u8)

  # Write unpadded chunk size (could be odd)
  rw.fs.setPosition(currChunk.filePos + FourCCSize)
  rw.write(currChunk.size.uint32)
  rw.fs.setPosition(0, sspEnd)

  if rw.path.len > 0:
    # Add real (potentially padded) chunk size to the parent chunk size
    rw.path[^1].size += padToEven(currChunk.size) + ChunkHeaderSize

    # Because nesting is not allowed for non-group chunks, ending a non-group
    # chunk will always return us to a group chunk
    if not rw.inGroupChunk:
      rw.inGroupChunk = true

    rw.trackChunkSize = true


proc createRiffFile*(filename: string, formTypeId: string,
                     endian = littleEndian, bufSize: int = -1): RiffWriter =
  var rw = new RiffWriter
  rw.fs = openFileStream(filename, endian, fmWrite, bufSize)

  rw.path = newSeq[ChunkInfo]()
  rw.trackChunkSize = false

  let formId = case endian:
  of littleEndian: FourCC_RIFF
  of bigEndian:    FourCC_RIFX

  rw.doBeginChunk(formId)

  if not validFourCC(formTypeId):
    raise newException(RiffReadError,
      fmt"Invalid form type ID: {fourCCToCharStr(formTypeId)}")

  rw.writeFourCC(formTypeId)
  rw.inGroupChunk = true

  result = rw


proc close*(rw) =
  ## Closes all currently open chunks (by calling `endChunk()`), updates the
  ## size of the root RIFF chunk, and closes the RIFF writer.
  ##
  ## It is very important to call this method at the end to ensure that all
  ## chunk sizes are correctly updated in the file!
  ##
  ## Raises a `RiffReadError` if the writer is closed or not initialised.
  rw.checkNotClosed()
  while rw.path.len > 0:
    rw.endChunk()
  rw.fs.close()
  rw.fs = nil
  rw.closed = true

# }}}

# vim: et:ts=2:sw=2:fdm=marker
