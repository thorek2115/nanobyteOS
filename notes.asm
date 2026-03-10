; What happens when you power on your PC?
; 1. BIOS code is copied from a ROM chip to RAM
; 2. BIOS starts executing code
;   - BIOS firmware initializes CPU, memory and other hardware componenets
;   - runs some tests (POST - power-on self test, 
;     checks memory, ensuring all essentials devices are operational)
; 3. BIOS searches for an OS to start
; 4. BIOS loads and starts the OS
; 5. OS runs

; Two ways of loading an OS:
; 1. Legacy booting:
; - BIOS checks the boot order setting to find the boot device
; - BIOS loads first sector of each bootable device into memory (at location 0x7C00)
; - BIOS looks for the Master Boot Record (MBT) (first 512 bytes of the boot device)
; - BIOS checks for 0xAA55 signature at the end of the sector
; - if found it starts executing code
; 2. EFI:
; - BIOS looks into special EFI partitions
; - OS must be compiled as an EFI program

; Memory segmentation:
;  - 0x1234:0x5678
;  - segment:offset
;  - each segment contains 64KB of memory
;  - segments overlap every 16 bytes
;  - real_address = segment * 16 + offset
;  - there are multiple ways of addressing the same location in memory
;
; segment:offset    real address
; 0x0000:0x7C00        0x7C00
; 0x0001:0x7BF0        0x7C00
; 0x0010:0x7B00        0x7C00
; 0x00C0:0x7000        0x7C00
; 0x07C0:0x0000        0x7C00

; These registers are used to specify currently active segments:
; CS - currently running code segment
; DS - data segment
; SS - stack segment
; ES, FS, GS - extra (data) segments

; Referencing a memory location:
; segment:[base + index * scale + displacement]
; All fields are optional:
;  segment: CS, DS, ES, FS, GS, SS 
;  if unspecified: SS when base register is BP 
;                  DS otherwise
;  base: (16 bits) BP/BX
;        (32/64 bits) any general purpose register
;  index: (16 bits) SI/DI
;         (32/64 bits) any general purpose register
;  scale: (32/64 bits only) 1, 2, 4 or 8
;  displacement: a (signed) constant value

; var: dw 100
; mov ax, var   ; copy offset to ax
; mov ax, [var] ; copy memory contents
;
; array: dw 100, 200, 300
; mov bx, array     ; copy offset to ax
; mov si, 2 * 2     ; array[2], words are 2 bytes wide
; mov ax, [bx + si] ; copy memory contents

; The stack:
; - memory accessed in a LIFO (last in, first out) manner using push and pop
; - used to save the return address when calling functions
; - it grows downwards
;    +--+--+--+------------+
;    |cc|bb|aa| Our OS ... |
;    +--+--+--+------------+
;    ^  ^  ^  ^
; 994 996 998 1000
; sp  sp   sp  sp
; sp - stack pointer points to the top of the stack
; when pushing, sp is decremented by the number of bytes pushed

; Interrupt:
; A signal which makes the processor stop what it's doing, in order to handle that signal
;
; Can be triggered by:
;  1. An exception (dividing by zero, segmentation fault, page fault)
;  2. Hardware (keyboard key pressed or released, timer tick, disk controller finished an operation)
;  3. Software (through the int instruction)
; 
; Examples of BIOS interrupts:
; int 0x10 -> Video
; int 0x11 -> Equipment check 
; int 0x12 -> Memory Size 
; int 0x13 -> Disk I/O 
; int 0x14 -> Serial Comunications
; int 0x15 -> Cassette 
; int 0x16 -> Keyboard I/O
;
; BIOS int 0x10:
; ah = 0x00 -> Set Video Mode
; ah = 0x01 -> Set Cursor Shape
; ah = 0x02 -> Set Cursor Position
; ah = 0x03 -> Get Cursor Position and Shape
; ...
; ah = 0x0E -> Write Character in TTY Mode
; ...
;
; BIOS int 0x10, ah = 0x0E:
; Prints a character to the screen in TTY Mode
;
; ah = 0x0E
; al = ASCII character to write
; bh = page number (text modes)
; bl = foreground pixel color (graphics mode)
;
; returns: nothing
;
;  - cursor advances after write
;  - characters BEL (7), BS (8), LF (A), CR (D) are treated as control codes

; Bootloader:
;  - loads basic components into memory
;  - puts system in expected state
;  - collects information about system

; Why floppy disk?
;  - ease of use
;  - universal support
;  - FAT12 - one of the simplest file systems

; Disk layout:
;  - each ring is track or cylinder
;  - each pizza slice is sector
;  - 8 heads (each side of a platter), 4 platters


; LBA to CHS conversion:
;  - sectors per track/cylinder (on a single side)
;  - heads per cyilnder (or just heads)
;
; CHS - cylinder-head-sector
; LBA - logical block addressing (0, 1, ...)
;
; track = LBA / sectors per track
; sector = LBA % sectors per track + 1
; head = LBA / sectors_per_track % heads
; cylinder = LBA / sectors_per_track / heads
;
; CHS to LBA conversion:
; LBA = (C * TH * TS) + (H * TS) + (S - 1)
; C  -> sector cylinder number
; TH -> total headers on disk
; TS -> total sections on disk
; H  -> sector head number
; S  -> sector's number

; int 13,2 - Read Disk Sectors
; ah = 0x02
; al = number of sectors to read (1-128)
; ch = track/cylinder number (0-1023), 6-15 bits
; cl = sector number (1-17), 0-5 bits
; dh = head number (0-15)
; dl = drive number (0=A:, 1=2nd floppy, 0x80=drive 0, 0x81=drive 1)
; es:bx = pointer to buffer
;
; CX =        ---CH--- ---CL---
; cylinder  : 76543210 98
; sector    :            543210
;
; returns:
; ah = status
; al = number of sectors read
; cf = 0 if successful
;    = 1 if error

; File system is a method of organizing pieces of data (files) on a disk
; NTFS:
;  - default on Windows
;  - supports many advanced features (journaling, compression, encryption)
;
; FAT family:
;  - default in older Windows (9x, 3.x) and MS-DOS
;  - FAT32 and exFAT still commonly used on flash drives and embedded devices
;  - very easy to learn, but also very simple
;
; APFS:
;  - default in MAC OS X (starting from High Sierra)
;  - was built to address the many limitations in previously used HFS+
;  - has many advanced features (snapshots, encryption, compression, crash protection)
;
; HFS+:
;  - default in older versions of Mac OS X (prior to High Sierra)
;  - derived from HFS (an old file system introduced with the first Macs)
;  - has gotten many features over the years (jornaling, compression, encryption),
;    but was replaced as it was showing his age
;
; ext family:
;  - most commonly used on Linux systems
;  - ext3 introduced journaling

; FAT12:
; Disk: reserved | file allocation tables | root directory | data      
;          1                18                    14
;
; reserved = reserved_sectors = 1 sector
; FATs = fat_count * sectors_per_fat = 2 * 9 = 18 sectors
; root = (dir_entry_count * 32) / bytes_per_sector = (224 * 32) / 512 = 14 sectors (if it's not integer, round up)
;
; The root directory:
; File name    Attr.     Creation      Creation  Creation  Access   First cluster  Modified   Modified  First cluster  Size
;                        time (1/10s)  time      date      date     (high)         time       date      (low)
; NBOS         Vol label     0         13:23:05  3/1/26    3/1/26         0        13:23:05   3/1/26          0        0
; KERNEL  BIN  Archive       0         13:23:05  3/1/26    3/1/26         0        13:23:05   3/1/26          2        55
; TEST    TXT  Archive       0         00:08:49  2/28/26   2/28/26        0        00:08:49   2/28/26         3        6743
; <empty>
;
; LBA = data_region_begin + (cluster - 2) * sectors_per_cluster
; LBA = 1+18+14 + (3 - 2) * 2 = 35
; 
; The file allocation table:
; F0 FF FF FF 4F 00 05 60 00 07 80 00 09 A0 00 0B
; C0 00 0D E0 00 0F 00 01 11 20 01 FF 0F 00 00 00
; 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
;
; FF0 FFF FFF 004 005 006 007 008 009 00A
; 00B 00C 00D 00E 00F 010 011 012 FFF 000
; 000 000 000 000 000 000 000 000 000 000
; 
; Entry size:
; FAT 12 -> 12 bits
; FAT 16 -> 16 bits
; FAT 32 -> 32 bits
;
; until cluster number is FF8 (end of the chain = end of the file)
; AB CD EF -> DAB EFC
;
; Reading files from directories:
;  1. Split path into components parts (and convert to FAT file naming scheme)
;   Home\Documents\hello.txt    =>    "HOME       ", "DOCUMENTS  ", "HELLO   TXT"
;  2. Read first directory from root directory, using same procedure as reading files.
;     Directories have the same structure as the root directory, and can be read just like an ordinary file.
;  3. Search the next component from the path in the directory, and read it
;  4. repeat until reaching and reading the file

; Watcom compiler:
;
;
;

;
;
;

; CDECL calling convention:
; arguments:
;  - passed through stack
;  - pushed from right to left
;  - caller removes parameters from stack
; return:
;  - integers, pointers: ax or eax
;  - floating point: st0
; registers:
;  - eax, ecx, edx saved by caller
;  - all others saved by callee
; name mangling: C functions are prepended with a _
;

; printf implementation:
; int printf(const char* format, ...);
; %[flags][width][.precision][length]specifier
;
; Specifier:
; +-----------+---------------------------+----------+
; | specifier |          output           | example  |
; +-----------+--------------------------------------+
; |  d or i   |   signed decimal integer  |   235    |
; |     u     | unsigned decimal integer  |   6705   |
; ...

; 


; Protected Mode:
; History w processors:
; 1977 | Apple II
; 1978 | Intel 8086
; 1979 | Intel 8088 (cheaper 8086 having only 8 data lines)
; 1979 | Motorola 68000
; 1981 | IBM PC (8088)
; 1984 | Apple Macintosh
; 