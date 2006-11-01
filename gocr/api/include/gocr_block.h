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
 

#ifndef _GOCR_BLOCK_H 
#define _GOCR_BLOCK_H 

#ifndef _GOCR_MODULE_H
# error "Do not call gocr_gui.h directly; call gocr_module.h instead."
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*! \file gocr_block.h
  \brief This is the block header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/*
 * block definition
 */
/** @name Block
  */
/*@{*/
typedef int gocr_blockType;


typedef int gocr_blockId;

/**
  \brief This is the block parent structure.
*/
struct gocr_block {
	gocr_blockType	t;
	gocr_blockId	id;

	int		x0, y0, x1, y1;		/**< boundaries in main image */
	gocr_Image	*image;			/**< image of this block */
	
	gocr_List	boxlist;		/**< List of boxes in this block */

	struct {
		unsigned int	min_height, max_height;
		unsigned int	min_width, max_width;
		float		av_height, av_width;
	} boxinfo;				/**< statistics of the boxes found */

	wchar_t		*text;
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_block gocr_Block;

struct gocr_line {
	int		x0, x1;		/* x-boundaries */
	int		m0, m1, m2, m3; /* y-boundaries */
};
typedef struct gocr_line gocr_Line;

struct gocr_textblock {
	gocr_Block	b;			/* parent; must be first field */
};
typedef struct gocr_textblock gocr_TextBlock;

struct gocr_pictureblock {
	gocr_Block	b;			/* parent; must be first field */
	char		*name;
};
typedef struct gocr_pictureblock gocr_PictureBlock;

struct gocr_mathblock {
	gocr_Block	b;			/* parent; must be first field */

	/* to be done */
};
typedef struct gocr_mathblock gocr_MathBlock;

extern gocr_List		blocklist;
extern gocr_blockType gocr_blockTypeRegister ( char *name );
extern gocr_blockType gocr_blockTypeGetByName ( char *name );
extern const char *gocr_blockTypeGetNameByType ( gocr_blockType t );

extern int gocr_blockAdd ( gocr_Block *b );
/*@}*/

#ifdef __cplusplus
}
#endif

#endif /* _GOCR_MODULE_H */
