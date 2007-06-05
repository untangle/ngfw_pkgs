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

#ifndef _GOCR_CHAR_H
#define _GOCR_CHAR_H

#ifndef _GOCR_MODULE_H
# error "Do not call gocr_gui.h directly; call gocr_module.h instead."
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*! \file gocr_char.h
  \brief This is the character header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/* 
 * character frame
 */
/** @name Character
*/
/*@{*/
/**
  \brief This is the character structure.
  \sa gocr_Box.
*/
struct gocr_char {
	wchar_t		c;			/**< character */
	float		prob;			/**< probability */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_char gocr_Char;

/**
  \brief This is the box structure.
*/
struct gocr_box {
	int		x0, y0, x1, y1;		/**< frame (relative to block) */
	wchar_t		*attributes;		/**< character attributes */
	gocr_Image	*image;			/**< shared image */

	gocr_List	possible;		/**< list of possible chars */
	gocr_Char	*ch;			/**< pointer to chosen char */
	wchar_t		modifier;		/**< default=0, see compose() in unicode.c */

	/* provided for compatibility only, deprecated. */
	wchar_t		c, ac;			/**< detected (alternate) */
	int		num;			/**< same nummer = same char */
	int		x, y, dots;		/**< reference-pixel, i-dots */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_box gocr_Box;

enum gocr_charattributetype {
	SETTABLE, UNTIL_OVERRIDEN
};
/**
  \brief Typedef encapsulation.
*/
typedef enum gocr_charattributetype gocr_CharAttributeType;
/*@}*/

/*
 * charFinder functions 
 */
/** @name charFinder functions 
  */
/*@{*/

#define GOCR_SET	1
#define GOCR_UNSET	0

extern int gocr_charBegin ( void );
extern int gocr_charEnd ( void );
extern int gocr_charSetAllNearPixels ( int action, int x, int y , int connect );
extern int gocr_charSetAttribute ( int action, char *name, ... );
extern int gocr_charSetPixel ( int action, int x, int y );
extern int gocr_charSetRect ( int action, int x0, int y0, int x1, int y1 );
/*@}*/

/*
 * charRecog functions
 */
/** @name charRecog functions 
  */
/*@{*/
extern int gocr_charAttributeRegister ( char *name, gocr_CharAttributeType t,
	char *format );
extern int gocr_charAttributeInsert ( char *name, ... );
extern int gocr_boxCharSet( gocr_Box *b, wchar_t w, float prob );
/*@}*/

#ifdef __cplusplus
}
#endif

#endif
