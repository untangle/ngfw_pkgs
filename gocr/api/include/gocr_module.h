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
 
#ifndef _GOCR_MODULE_H 
#define _GOCR_MODULE_H 

#ifdef __cplusplus
extern "C" {
#endif

/* header for modules. */
#include <stdio.h>
#include "hash.h"
#include "gocr_list.h"
#include "unicode.h"
#include "gocr_image.h"
#include "gocr_char.h"
#include "gocr_block.h"
#include "gocr_gui.h"
#include "gocr.h"

/*! \file gocr_module.h
  \brief This is the module header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/** @name Module data.
  */
/*@{*/

/** \brief Module function information

*/
struct gocr_modulefunctioninfo {
	char			*function;		/**< Function name. */
	char			*description;		/**< Function description. */
	gocr_ModuleType	 	type;			/**< Function type. */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_modulefunctioninfo gocr_ModuleFunctionInfo;

/** \brief Module package attributes information

*/
struct gocr_moduleattributeinfo {
	char			*name;			/**< Field name. */
	char			*description;		/**< Field description. */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_moduleattributeinfo gocr_ModuleAttributeInfo;

struct gocr_moduleinfo {
	char			*name;			/**< Module name. */
	char			*version;		/**< Module version. */
	char			*authors;		/**< Module authors. */

	gocr_ModuleFunctionInfo	*functions;		/**< Module functions. */
	gocr_ModuleAttributeInfo *attributes;		/**< Module attributes. */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_moduleinfo gocr_ModuleInfo;
/*@}*/


/** @name Debugging utilities
  */
/*@{*/

extern int gocr_printArea ( gocr_Image *image, int x0, int y0, int x1, int y1 );
extern int gocr_printBlock ( gocr_Block *b  );
extern int gocr_printBox ( gocr_Box *b );
extern int gocr_printBox2 ( gocr_Box *b1, gocr_Box *b2 );
/*@}*/

#ifdef __cplusplus
}
#endif

#endif /* _GOCR_MODULE_H */
