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
format). What I personally think is
really good for is implementing your own hierarchical binary file
formats (for example, [Gridmonger](https://github.com/johnnovak/gridmonger)
stores its documents in RIFF format). It is an excellent alternative to
~~bloated garbage like XML~~ other hierarchical file formats less suitable for
storing binary data, such as XML.

To learn more about RIFF, please refer to the [References & reading materials
section](#references-reading-materials-section).



### Main features

* Reading/writing of little-endian (`RIFF`) and big-endian (`RIFX`) RIFF files
* Strict adherence to the RIFF standard
* Convenient helper methods to navigate the chunk hierarchy
* Cursor support

### Use it if

* You need to store hierarchical binary data in an efficient and extensible way
* You don't want to deal with the parsing overhead of other formats like
  XML, JSON, etc. (such formats are ill-suited for binary data anyway)
* You're an Amiga fan — true Amiga fans try to use IFF-like formats as much as
  possible :sunglasses:

### Don't use it if

* You need to store more than 4 GB in a single chunk or file
* You want to read data from malformed RIFF files or you want to attempt to
  repair them, in which case this library is not a good fit for you because it
  expects perfect RIFF files with no errors. Repairing RIFF files
  generically is not really possible without some extra knowledge about the
  particular file format you're dealing with (e.g. WAV, AVI, etc.), so
  you'll probably need to something custom anyway.

## Installation

**nim-riff** can be installed via Nimble:

    nimble install riff


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
r = = openRiffFile("infile")
r = openRiffFile("infile", bufsize=8192)

var f = open("infile")
r = openRiffFile(f)
r = openRiffFile(f, bufSize=8192)

r.close()
```


#### Navigating the chunks

The reader has the concept of the *current chunk*, you can think of it as
a cursor. Right after successfully opening a file, the current chunk is set to
the root RIFF chunk (which is a group chunk itself). Moreover, we're already
inside the root group chunk so we don't need to call `enterGroup()` (more on
that later).

The `currentChunk()` method returns information about the current chunk as
a `ChunkInfo` object, which has the following fields:

* `id` *string* – 4-char chunk ID (FourCC)

* `size` *uint32* – chunk data length in bytes (not including the 8-byte
   chunk headers and the optional padding byte if the length is odd)

* `filePos` *int64* – absolute file position of the first byte of the chunk

* `kind` *ChunkKind* – `ckGroup` for group chunks (`RIFF` and `LIST`), `ckChunk` for normal chunks

* `formatTypeId` *string* – for group chunks only: format type FourCC of the group

`nextChunk()` moves the cursor to the next chunk within the current group
chunk and returns its `ChunkInfo`, or raises an error if we're already at the
last subchunk. To prevent these errors, it's best to use it in conjunction
with `hasNextChunk()`.

This is a simple example that iterates through all the top-level chunks in the
root RIFF group chunk and prints out their chunk infos:

```nim
import riff

var r = openRiffFile("test.wav")
echo r.currentChunk

while r.hasNextChunk():
  let ci = r.nextChunk()
  echo ci

r.close()
```

##### Group chunks

As mentioned above, a chunk can be either a normal chunk (`ckChunk`) or
a group chunk (`ckGroup`) that can contain further subchunks. There are just
two types of group chunks: the root `RIFF` chunk, and `LIST` chunks.

When the cursor is at a group chunk, you can call `enterGroup()` to descend
into it. You'll still need to call `nextChunk()` to move the cursor to the
first subchunk in that group. When opening a RIFF file, there is an implicit
`enterGroup()` call made on the root RIFF chunk for convenience, so we can
just call `nextChunk()` to move the cursor to the first top-level subchunk.

`exitGroup()` does the opposite; it moves the cursor up one level to the
parent group chunk.


##### Recursive chunk walking example

The chunk hierarchy in a RIFF file is basically a tree structure and we can
walk this tree with the aforementioned navigation methods:

* `enterGroup()` moves the cursor to the first child node of the current parent node
* `exitGroup()` moves the cursor back to the parent node
* `nextChunk()` iterates the cursor through the child nodes

To put this all together, the below program walks through all the chunks in
a file recursively, and prints out the chunk infos in a hierarchical fashion:

```nim
import riff

proc printChunks(r: RiffReader) =
  proc walkChunks(depth: Natural = 1) =
    while r.hasNextChunk():
      let ci = r.nextChunk()
      echo " ".repeat(depth*2), ci
      if ci.kind == ckGroup:
        r.enterGroup()
        walkChunks(depth+1)
    r.exitGroup()

  echo r.currentChunk
  walkChunks()

var r = openRiffFile("test.grm")
printChunks(r)
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

You can think of the current chunk as a virtual file; when you enter a chunk
with `nextChunk()`, the "virtual file position", or *chunk position*, is set to
the start of the chunk data, which is the first byte after the chunk headers.
This is chunk position `0`.

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

r.readBStr()    # read a Pascal-style string # (one `length` leading
                # byte followed by `length` bytes of character data)

r.readWStr()    # read a Pascal-style string
                # (16-bit (word) leading `length` value)

r.readZStr()    # read a C-style null-terminated string

r.readBZStr()   # read a Pascal-style string (byte `length`) that is also
                # null-terminated

r.readWZStr()   # read a Pascal-style string (16-bit `length`) that is also
                # null-terminated
```

It is also possible to save the current chunk and chunk position as a *cursor*
and restore it later. A typical usage pattern is to walk through all the
chunks in the file in the first pass and store cursors pointing to the chunks
of interest, and then read from those chunks in the second pass using the
cursors.

```nim
let cur = r.cursor    # store the current cursor
r.cursor = cur        # restore a cursor
```


### Writing RIFF files

TODO


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

Copyright © 2019-2020 John Novak <<john@johnnovak.net>>

This work is free. You can redistribute it and/or modify it under the terms of
the [Do What The Fuck You Want To Public License, Version 2](http://www.wtfpl.net/), as published
by Sam Hocevar. See the [COPYING](./COPYING) file for more details.


