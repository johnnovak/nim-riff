# nim-riff

## Overview 

**nim-riff** is a library for reading and writing [Resource Interchange File
Format (RIFF)](https://en.wikipedia.org/wiki/Resource_Interchange_File_Format)
files. RIFF is heavily inspired by Electronic Arts' [Interchange File Format
(IFF)](https://en.wikipedia.org/wiki/Interchange_File_Format), introduced in
1985 on the best personal computer ever, the legendary [Commodore
Amiga](https://en.wikipedia.org/wiki/Amiga).

If we're only considering existing file formats, a generic RIFF library like
this has little use outside of handling
[WAV](https://en.wikipedia.org/wiki/WAV),
[AVI](https://en.wikipedia.org/wiki/Audio_Video_Interleave) and
[WebP](https://en.wikipedia.org/wiki/WebP) files (the most common RIFF based
format). What I personally think it is
really good for, though, is implementing your own hierarchical binary file
formats (for example, [Gridmonger](https://github.com/johnnovak/gridmonger)
stores its documents in RIFF format). It is an excellent alternative to
~~bloated garbage like XML~~ other hierarchical file formats less suitable for
storing binary data, such as XML.

To learn more about RIFF, please refer to the [References & reading materials
section](#references--reading-materials).



### Main features

* Reading and writing of little-endian (`RIFF`) and big-endian (`RIFX`) RIFF files
* Strict adherence to the RIFF standard
* Convenient helper methods to navigate the chunk hierarchy (with cursor support)
* The reader treats chunks as virtual files
* The writer recursively auto-updates all parent chunk sizes to minimise the
  chance of creating malformed files

### Use it if

* You need to store hierarchical binary data in an efficient and extensible way
* You don't want to deal with the parsing overhead of other formats like
  XML, JSON, etc. (such formats are ill-suited for binary data anyway)
* You're an Amiga fan — true Amiga fans hunt for opportunities to use IFF-like
  formats as much as possible :sunglasses:

### Don't use it if

* You need to store more than 4 GB in a single chunk or file
* You want to read data from malformed RIFF files, or you want to attempt to
  repair them. For these use cases this library is not a good fit because it
  expects perfect RIFF files with no errors. Repairing RIFF files
  generically is not really possible without some extra knowledge about the
  particular file format you're dealing with (e.g. WAV, AVI, etc.), so
  you'll probably need to something custom anyway.

## Installation

**nim-riff** can be installed via Nimble:

    nimble install riff


## Compiling the examples

The examples require the `simple_parseopt` module, so install that first:

    nimble install simple_parseopt

Then you can compile the examples in debug or release mode:

    nimble examples
    nimble examplesDebug


## Usage

### Reading RIFF files

#### Opening a file

To open a RIFF file for reading, you'll need to provide a filename or an
existing file handle to the `openRiffFile()` proc. You can also optionally
override the default buffer size.

This will create a `RiffReader` object on success, or raise
a `RiffReaderError` if something went wrong (just like all reader methods in
case of an error).

When you're done with a reader, you can close it with the `close()` method.

```nim
import riff

var r: RiffReader
r = openRiffFile("infile")
r = openRiffFile("infile", bufsize=8192)

var f = open("infile")
r = openRiffFile(f)
r = openRiffFile(f, bufSize=8192)

r.close()
```


#### Navigating the chunks

The reader has the concept of the *current chunk*, you can think of it as
a cursor. Right after successfully opening a file, the current chunk is set to
the root RIFF chunk, which is a group chunk itself.

The `currentChunk()` method returns information about the current chunk as
a `ChunkInfo` object, which has the following fields:

* `id` *string* – 4-char chunk ID (FourCC)

* `size` *uint32* – chunk data length in bytes (not including the 8-byte
   chunk headers, nor the optional padding byte if the length is odd)

* `filePos` *int64* – absolute file position of the chunk (the first byte of the chunk
   header)

* `kind` *ChunkKind* – `ckGroup` for group chunks (`RIFF` and `LIST`), `ckChunk` for normal chunks

* `formatTypeId` *string* – for group chunks only: format type FourCC of the group

`nextChunk()` moves the cursor to the next chunk within the current group
chunk and returns its `ChunkInfo`, or raises an error if we're already at the
last subchunk. It's best to use `hasNextChunk()` before calling `nextChunk()`
to prevent these errors.

This is a simple example that iterates through all the top-level chunks in the
root RIFF group chunk, and prints out their chunk infos:

```nim
import riff

var r = openRiffFile("test.wav")
var ci: ChunkInfo

# info about the root RIFF chunk
ci = r.currentChunk
echo ci

# the root RIFF chunk is a group chunk so it must be entered
if r.hasSubChunks():
  ci = r.enterGroup()
  echo ci

  # iterate through all top-level chunks inside the root RIFF group chunk
  while r.hasNextChunk():
    ci = r.nextChunk()
    echo ci

r.close()
```

##### Group chunks

As mentioned above, a chunk can be either a normal chunk (`ckChunk`) or
a group chunk (`ckGroup`) that can contain further subchunks. There are only
two types of group chunks: the root `RIFF` chunk, and `LIST` chunks.

When the cursor is at a group chunk, you can call `enterGroup()` to descend
into it. If the group contains subchunks (which can be checked with the
`hasSubChunks()` method), the cursor will be set to the first child chunk, and
the chunk info will be returned. If the group has no subchunks, an error will
be raised.

`exitGroup()` does the opposite; it moves the cursor up one level to the
parent group chunk.


##### Walking the chunk tree

The chunk hierarchy of a RIFF file is basically a tree structure, and we can
walk this tree with the aforementioned navigation methods:

* `enterGroup()` moves the cursor to the first child node of the current group node
* `exitGroup()` moves the cursor back to the parent node
* `nextChunk()` iterates the cursor through sibling nodes

Using these methods, it is possible to put together a recursive algorithm that
traverses the whole chunk tree and prints out the chunk infos in
a hierarchical fashion:

```nim
import strutils
import riff

var r = openRiffFile("test.grm")

proc walkChunks(depth: Natural = 0) =
  let cc = r.currentChunk
  echo " ".repeat(depth * 2), cc

  if cc.kind == ckGroup:
    if r.hasSubchunks:
      discard r.enterGroup()
      walkChunks(depth+1)
      r.exitGroup()
    else:
      echo " ".repeat((depth+1) * 2), "<empty>"

  if r.hasNextChunk:
    discard r.nextChunk()
    walkChunks(depth)

walkChunks()

r.close()
```

The library provides a convenient `walkChunks()` iterator that does
effectively the same thing but without recursion. It can also traverse
subtrees and use any node as the starting point.

```nim
import strutils
import riff

var r = openRiffFile("test.grm")

for ci in r.walkChunks():
  echo " ".repeat((r.cursor.path.len-1) * 2), ci

r.close()
```


Example output ([Gridmonger](/johnnovak/gridmonger) map file):

```
(id: "RIFF", size: 5582, filePos: 0, kind: ckGroup, formatTypeId: "GRMM")
  (id: "map ", size: 23, filePos: 12, kind: ckChunk)
  (id: "LIST", size: 5508, filePos: 44, kind: ckGroup, formatTypeId: "lvls")
    (id: "LIST", size: 5496, filePos: 56, kind: ckGroup, formatTypeId: "lvl ")
      (id: "prop", size: 20, filePos: 68, kind: ckChunk)
      (id: "cell", size: 5445, filePos: 96, kind: ckChunk)
      (id: "note", size: 2, filePos: 5550, kind: ckChunk)
  (id: "lnks", size: 2, filePos: 5560, kind: ckChunk)
  (id: "disp", size: 11, filePos: 5570, kind: ckChunk)
```

#### Reading chunk data

You can think of the current chunk as a virtual file; when you enter a chunk,
the "virtual file position", or *chunk position*, is set to the start of the
chunk data, which is the first byte after the chunk headers.  This is chunk
position `0`.

You can query the current chunk position with `getChunkPos()` and set it with
`setChunkPos()`, which works similarly to `setFilePosition()` from the
standard `io` library. An error will be raised if you try to set the position
beyond the limits of the chunk. 

```nim
let pos = r.getChunkPos()
r.setChunkPos(20, cspSet)   # valid values are: cspSet, cspCur, cspEnd
```

You can read the chunk data with the various `read*()` methods as shown below.
An error will be raised if you attempt to read past the end of the chunk.


```nim
# To read a specific numeric type, pass in its type as an argument
let i8 = r.read(uint8)
let f32 = r.read(float32)
let i64 = r.read(int64)

# Reading multiple values into a buffer
var buf: array[100, float]
r.read(buf, startIndex=0, numValues=buf.len)

r.readChar()          # read a char
r.readFourCC()        # read a FourCC as a string
r.readStr(length=10)  # read the next 10 bytes as a string

r.readBStr()    # read a Pascal-style string (one `length` leading
                # byte followed by `length` bytes of character data)

r.readWStr()    # read a Pascal-style string
                # (16-bit (word) leading `length` value)

r.readZStr()    # read a C-style null-terminated string

r.readBZStr()   # read a Pascal-style string (byte `length`) that is also
                # null-terminated

r.readWZStr()   # read a Pascal-style string (16-bit `length`) that is also
                # null-terminated
```

#### Cursors

It is possible to save the current chunk and chunk position as a `Cursor`
and restore it later. 

```nim
let cur = r.cursor    # store the current cursor
r.cursor = cur        # restore a cursor
```

The `Cursor` object has the following fields:

* `path` *seq[ChunkInfo]* – path to this chunk in the RIFF tree (the last
    element is this chunk, the rest are the parents, right up to the root RIFF
    chunk which is the first element)

* `chunkPos` *uint32* – chunk position from the start of the chunk data

* `filePos` *int64* – absolute file position from the start of the file


A typical usage pattern is to walk through all the
chunks in the file in the first pass, store cursors pointing to the chunks
of interest, and then read from those chunks in the second pass using the
cursors.



### Writing RIFF files

#### Creating a file

You can create a new RIFF file with the `createRiffFile()` method.  This will
create a `RiffWriter` object on success, or raise a `RiffWriterError` if
something went wrong (just like all writer methods in case of an error).
You can also optionally set the endianness of the file (default is
little-endian) or override the default buffer size.


```nim
var w: RiffWriter
w = createRiffFile(filename, "GRMM")
w = createRiffFile(filename, "GRMM", endian=littleEndian, bufSize=8192)
```

When you're done writing to the RIFF file, you must call the `close()` method.

:warning: _Calling `close()` is very important because this ensures that the
total file size in the root RIFF chunk is updated correctly! It also closes
all currently open chunks recursively, making sure their headers are updated
as well._

#### Creating chunks

You can create chunks or list chunks with the `beginChunk()` and
`beginListChunk()` methods, respectively. The chunk ID (or format type ID in
case of list chunks) needs to be passed in. 

Calling `endChunk()` closes the current chunk and writes the final chunk size
to its header.

The `close()` method closes all currently open chunks recursively.

```nim
w.beginListChunk("lvls")

w.beginChunk("cell")
# ... write chunk data ...
w.endChunk()

w.beginChunk("prop")
# ... write chunk data ...
w.endChunk()

w.endChunk() # end of 'lvls' list chunk
```

#### Writing chunk data

Writing values works analogously to the `read*()` methods:

```nim
w.write(42'u8)
w.write(-8765'i16)
w.write(1234.567'f64)

w.writeChar('!')
w.writeFourCC("ILBM")
w.writeStr("Guybrush Threepwood")
w.writeBStr("Mancomb Seepgood")
w.writeWStr("Elaine Marley")
w.writeZStr("Herman Toothrot")
w.writeBZStr("Men of Low Moral Fiber")
w.writeWZStr("Voodoo Lady")
```


## References & reading materials


[1] "EA IFF 85" Standard for Interchange Format Files  
*Electronic Arts, 1985*  
https://wiki.amigaos.net/wiki/EA_IFF_85_Standard_for_Interchange_Format_Files
http://www.martinreddy.net/gfx/2d/IFF.txt

[2] A Quick Introduction to IFF  
*AmigaOS Documentation Wiki*  
https://wiki.amigaos.net/wiki/A_Quick_Introduction_to_IFF

[3] Resource Interchange File Format  
*Wikipedia*  
https://en.wikipedia.org/wiki/Resource_Interchange_File_Format

[4] RIFF (Resource Interchange File Format)  
*Digital Preservation. Library of Congress*  
https://www.loc.gov/preservation/digital/formats/fdd/fdd000025.shtml

[5] Multimedia Programming Interface and Data Specifications 1.0  
*Microsoft / IBM, August 1991*  
http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/riffmci.pdf

[6] Multimedia Data Standards Update  
*Microsoft, April 1994*  
http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/RIFFNEW.pdf

[7] Exiftool - Riff Info Tags  
*ExifTool website*  
https://exiftool.org/TagNames/RIFF.html#Info

[8] Exchangeable image file format for digital still cameras, Exif Version 2.32  
*Camera & Imaging Products Association, May 2019*  
http://www.cipa.jp/std/documents/e/DC-X008-Translation-2019-E.pdf

[9] Audio Interchange File Format: "AIFF", Version 1.3  
*Apple, January 1989*  
http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf

[10] AVI RIFF File Reference  
*Microsoft Dev Center, May 2018*  
https://docs.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference


## License

Copyright © 2019-2021 John Novak <<john@johnnovak.net>>

This work is free. You can redistribute it and/or modify it under the terms of
the [Do What The Fuck You Want To Public License, Version 2](http://www.wtfpl.net/), as published
by Sam Hocevar. See the [COPYING](./COPYING) file for more details.


