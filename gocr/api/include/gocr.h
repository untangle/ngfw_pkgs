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
 

#ifndef _GOCR_API_H 
#define _GOCR_API_H 

#ifdef __cplusplus
extern "C" {
#endif

/*! \file gocr.h
  \brief This is the main header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/** \brief FALSE value.
*/
#define GOCR_FALSE 0
/** \brief TRUE value.
*/
#define GOCR_TRUE 1

/* 
 * Initialization/finalization
 */
/** @name Initialization/finalization 
  */
/*@{*/
extern int	gocr_init		( int argc, char **argv );
extern void	gocr_finalize		( void );
/*@}*/

/* gocr options */
/** @name GOCR attributes
  */
/*@{*/
/**
  \brief Attributes of GOCR API that can be set by the user.
*/
enum gocr_attributetype {
	LIBVERSION,		/**< Library version. */
	VERBOSE,		/**< Sets the verbose level.\ Minimum = 0, Maximum = 3.\ Default: 1. */

	BLOCK_OVERLAP,		/**< If true, allows blocks to overlap.\ Default: FALSE. */
	NO_BLOCK,		/**< If true, and no block was found, creates a block covering the entire image.\ Default: TRUE. */

	CHAR_OVERLAP,		/**< If true, allows characters to overlap.\ Default: TRUE. */
	CHAR_RECTANGLES,	/**< If true, all characters are rectangles.\ Default: TRUE. */
	FIND_ALL,		/**< If true, first find all characters, saving in memory, and then process. Default: FALSE */

	ERROR_FILE,		/**< A (FILE *) pointer, to which all error messages will be output.\ Default: stderr. */
	PRINT,			/**< An integer from 0 to 6, that... */
	PRINT_IMAGE		/**< If true, when a gocr_print* function is called it prints the image too.\ Default: TRUE. */
};
/**
  \brief Typedef encapsulation.
*/
typedef enum gocr_attributetype gocr_AttributeType;

extern int	gocr_setAttribute	( gocr_AttributeType t, void *value );
extern void *	gocr_getAttribute	( gocr_AttributeType t );
/*@}*/

/** @name Image
  */
/*@{*/
int 	(*gocr_imageLoad)		( const char *filename, void *data );
extern void	gocr_imageClose		( void );
/*@}*/

/*
 * Module system.
 *  
 */
/** @name Module system
  */
/*@{*/
/**
  \brief This is the module type list.
*/
enum gocr_moduletype {
	imageLoader = 0,	/**< loads image */
	imageFilter,		/**< operations done to image */
	blockFinder,		/**< operations to separate image in blocks,
				    detect pictures, layout, font type, etc */
	charFinder,		/**< find individual characters in blocks */
	charRecognizer,		/**< recognize characters individually */
	contextCorrection,	/**< works on unrecognized characters */
	outputFormatter,	/**< outputs the recognized text */
	allModules		/**< number of modules */
};
/**
  \brief Typedef encapsulation.
*/
typedef enum gocr_moduletype gocr_ModuleType;

typedef int gocr_ModuleId;
typedef int gocr_ModuleFunctionId;

extern gocr_ModuleId	gocr_moduleLoad	( char *filename );
extern void		gocr_moduleClose	( gocr_ModuleId id );
extern int		gocr_moduleSetAttribute	( gocr_ModuleId id, char *a, 
				char *b );
extern const struct gocr_moduleattributeinfo *
		gocr_moduleGetAttributeList 	( gocr_ModuleId id );
extern const struct gocr_modulefunctioninfo *
		gocr_moduleGetFunctionList 	( gocr_ModuleId id );

extern gocr_ModuleFunctionId	
		gocr_functionInsertBefore	( char *functionname, 
				gocr_ModuleId mid, void *data, 
				gocr_ModuleFunctionId func );
extern gocr_ModuleFunctionId	
		gocr_functionAppend	( char *functionname, 
				gocr_ModuleId mid, void *data);
extern void *		gocr_functionDeleteById	( gocr_ModuleFunctionId id );

/*extern int		gocr_runModuleFunction	( gocr_ModuleFunctionId id );
extern int		gocr_runModuleType	( gocr_ModuleType t ); */
extern int		gocr_runAllModules	( void );
/*@}*/


/** @name GUI functions
  */
/*@{*/
enum gocr_guifunction {
	gocr_BeginWindow,
	gocr_EndWindow,
	gocr_DisplayCheckButton,
	gocr_DisplayImage,
	gocr_DisplayRadioButtons,
	gocr_DisplaySpinButton,
	gocr_DisplayText,
	gocr_DisplayTextField
};
typedef enum gocr_guifunction gocr_GUIFunction;

extern int	gocr_guiSetFunction	( gocr_GUIFunction type, void *func );

/*@}*/

#ifdef __cplusplus
}
#endif


#endif /* GOCR_API_H */
