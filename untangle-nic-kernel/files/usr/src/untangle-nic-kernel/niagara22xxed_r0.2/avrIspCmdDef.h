#ifndef AVR_SPI_PROG_H
#define AVR_SPI_PROG_H

#define  PROG_ENABLE_1				0xac
#define  PROG_ENABLE_2				0x53
#define  PROG_ENABLE_3				0x00
#define  PROG_ENABLE_4				0x00

#define  CHIP_ERASE_1				0xac
#define  CHIP_ERASE_2				0x80
#define  CHIP_ERASE_3				0x00
#define  CHIP_ERASE_4				0x00

#define	 READ_PROG_1L				0x20
#define	 READ_PROG_1H				0x28
#define	 READ_PROG_2				0x00
#define	 READ_PROG_3				0x00

#define  LOAD_PROG_PAGE_1L                      0x40
#define  LOAD_PROG_PAGE_1H                      0x48
#define  LOAD_PROG_PAGE_2                       0x00
#define  LOAD_PROG_PAGE_3                       0x00
#define  LOAD_PROG_PAGE_4                       0x00

#define  WRITE_PROG_PAGE_1                      0x4C
#define  WRITE_PROG_PAGE_2                      0x00
#define  WRITE_PROG_PAGE_3                      0x00
#define  WRITE_PROG_PAGE_4                      0x00

#define	 WRITE_PROG_1L				0x40
#define	 WRITE_PROG_1H				0x48
#define	 WRITE_PROG_2				0x00
#define	 WRITE_PROG_3				0x00
#define	 WRITE_PROG_4				0x00

#define	 READ_EPROM_1				0xa0
#define	 READ_EPROM_2				0x00
#define	 READ_EPROM_3				0x00

#define	 WRITE_EPROM_1				0xc0
#define	 WRITE_EPROM_2				0x00
#define	 WRITE_EPROM_3				0x00
#define	 WRITE_EPROM_4				0x00

#define	 WR_LOCK_BIT_1				0xac
#define	 WR_LOCK_BIT_2 				0xe0
#define	 WR_LOCK_BIT_3				0x00
#define	 WR_LOCK_BIT_4				0x00

#define	 RD_LOCK_BIT_1				0x58
#define	 RD_LOCK_BIT_2 				0x00
#define	 RD_LOCK_BIT_3				0x00

#define	 RD_SIGN_BYTE_1				0x30
#define	 RD_SIGN_BYTE_2				0x00
#define	 RD_SIGN_BYTE_3				0x00

#define	 WR_FUSE_LOW_1				0xac
#define	 WR_FUSE_LOW_2				0xa0
#define	 WR_FUSE_LOW_3				0x00
#define	 WR_FUSE_LOW_4				0x00

#define	 WR_FUSE_HIGH_1				0xac
#define	 WR_FUSE_HIGH_2				0xa8
#define	 WR_FUSE_HIGH_3				0x00
#define	 WR_FUSE_HIGH_4				0x00

#define	 RD_FUSE_LOW_1				0x50
#define	 RD_FUSE_LOW_2				0x00
#define	 RD_FUSE_LOW_3				0x00

#define	 RD_FUSE_HIGH_1				0x58
#define	 RD_FUSE_HIGH_2				0x08
#define	 RD_FUSE_HIGH_3				0x00

#endif

