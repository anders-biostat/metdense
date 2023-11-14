## MetDense format specification

Version 0.1

### Overview

A MetDense contains five blocks, as follows:
- The Header Block contains the file type magic, the file version number, and the offset of the Chromosomes Block.
- The Cells block contains the number of cells and their names.
- The Data Block contains teh actual methylation calls in a densely packed, but randomly accessible format.
- The Positions block lists for each chromosome all CpG positions and their
- The Chromosome Block lists the names of chromosomes or contigs and the file offsets of their position information

When opening a MetDense file, the parser should first read the Header Block, and the Cells block, then jump to the start of the Chromosomes Block (as given in the Header Block) and proceed reading that one. This data should be kept in memory.

The data from the Positions and Data Blocks can be read on demand from disk.

### Header Block

- Bytes 0-7: The string "MetDense"
- Bytes 8-11: The major version number of the format spec as uint32 (for now: 0)
- Bytes 12-15: The minor version number as uint32 (for now: 1)
- Bytes 16-23: The offset (position in the file) of the Data block as uint64 (was uint32, bytes 16-19 in version 0.0)
- Bytes 24-31: The offset (position in the file) of the Chromosomes block as uint64 (was uint32, bytes 20-23 in version 0.0)

### Cells Block

This block starts with a unit32 giving the number of cells. This number will be denoted `ncells` in teh following. Within this specification, cells are understood to be numbered by indices running from `0` to `ncells-1`.

Folling  `ncells`, the file contains the names of all cells, as strings, each terminated with "\n" (`0x0a`). After `ncells` such strings have been read, the block ends.

However, after its end, the block is padded with zeroes, such that the next block starts at a position that is divisible by 4.

## Data block

This block contains the actual methylation calls as dense, packed matrix. The matrix has one row for each CpG position in the genome (CpG positions not covered by any cell may be omitted) and one column in for each cell.

It is arranged in row-major form, i.e. consecutive bytes correspond to data for the same position but different cells. Each CpG position ("position" in the following) is represented by a "row", which is an array of `4*ceil(ncells/16)` consecutive bytes, where each byte holds information for 4 cells, as follows:
  - The bit pattern 00 means that the position was not covered in the cell.
  - The bit pattern 01 means that the cell *unmethylated* at the position.
  - The bit pattern 10 means that the cell *methylated* at the position.
  - The bit pattern 11 is not used (or: may mean that the call was ambiguos)

The number of bytes per row is chosen such that the total length of the row is divisible by 4, and hence padded at the end with zeroes as needed.

Therefore, if the row for a given CpG position stars at file position `offset` and we
wish to get bit pattern for cell `i`, we need to read in the byte as file position

   `offset + ( i // 4 )`

(where `//` denotes integer division), and then look at this byte `b` with

   `( b >> ( (i%4)*2 ) ) & 0x03`,

where `>>` denotes bitwise right shift, `%` denotes modulo (i.e., remainder of the division), and `&` means bitwise and.

For efficiency reasons, it may be better to read four bytes (one uint32) per file access. Then, all the data for a given position can be accessed with a loop like this:

```
   seek( file, offset_for_row )
   cell_idx = 0
   while True:
      a = read( file, uint32 )
      for i in range(16):
         print( cell_idx, a & 0x03 )
         a >>= 2
         cell_idx += 1
         if cell_idx > ncells:
            break      
```

## Positions block

For each chromosome, a vector of uint32 values, giving the base-pair positions of all CpG sites recorded for this chromosome in the Data Block. Therefore, the Positions Block contains in total as many uints32 as there are matrix rows in the Data Block. Hence:

  length_in_bytes(DataBlock) / ceil(ncells/4) == length_in_bytes(PositionsBlock) / 4

## Chromosomes block

The file position, where this last block starts, is given in the Header Block (see above). This block contains, in order
- A single uint32, giving the number of chromosomes (`nchroms`)
- For each chromosome, a uint64 (uint32 for version 0.0) giving the file position where its positions vetcor starts in the Positions Block.
- Lastly, the names of the chromosomes, as strings, each terminated with `\n`.
