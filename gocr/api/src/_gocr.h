/*
GOCR Copyright (C) 2000  Joerg Schulenburg Joerg.Schulenburg@physik.uni-magdeburg.de 
GOCR API Copyright (C) 2001 Bruno Barberi Gnecco <brunobg@sourceforge.net>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
 

#ifndef _GOCR_INTERNAL_H 
#define _GOCR_INTERNAL_H 

/* hidden general header. */

#include <stdio.h>
#include <stdlib.h>
#include "config.h"
#include "gocr_module.h"

/*
 * debug
 */
#define _gocr_debug(level, command)	if ( level <= _data.verbose ) { command }
extern void _gocr_printf ( int level, char *function, char *format, ... );

/*
 * internal data
 */
struct _gocr_data {
	int		verbose; /* 0 = none, 3 = MAX */
	int		block_overlap;
	int		no_block;
	int		char_overlap;
	int		char_rectangles;
	int		find_all;
	FILE		*error;
	int		print;
	int		print_image;

	/* internal access only */
	int		lock;
};
typedef struct _gocr_data _gocr_Data;

extern _gocr_Data _data;
extern gocr_Block *currentblock;
extern gocr_Box *currentbox;


/*
 * init/end functions
 */
extern int _gocr_initModule ( void );
extern void _gocr_endModule ( void );

extern int _gocr_initBlock ( void );
extern void _gocr_endBlock ( void );

extern int _gocr_initImage ( void );
extern void _gocr_endImage ( void );

extern int _gocr_initUnicode ( void );
extern void _gocr_endUnicode ( void );

/*
 * utilities
 */
extern int _gocr_imageSharedCopy ( gocr_Image *orig, int x0, int y0, int x1, int y1,
			    gocr_Image *newimage );
extern int _gocr_imageCopy ( gocr_Image *orig, int x0, int y0, int x1, int y1,
			    gocr_Image *newimage );
extern void _gocr_fixParameters ( int *x0, int *x1, int *y0, int *y1 );

extern int _gocr_blockTextFill ( gocr_Block *b );
extern void _gocr_blockInfoFill ( gocr_Block *b );

extern int otsu ( gocr_Image *image, void *v );
#endif /* _GOCR_INTERNAL_H */
