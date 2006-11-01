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

#include "_gocr.h"
#include "gocr.h"
#include <stdarg.h>
#ifdef HAVE_PAM_H 
#include <pam.h>
#else if HAVE_PNM_H
#include <pnm.h>
#endif

#define MEM_DEBUG
#ifdef MEM_DEBUG
#include <mcheck.h>
#endif

static int loaded = 0;

_gocr_Data _data;

#define FUNCTION		"gocr_init"
/**
  \brief Inits the library.
 
  This function must be called before any other GOCR function.

  \param argc number of arguments.
  \param argv the arguments.
  \sa gocr_finalize.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_init ( int argc, char **argv ) {
	_gocr_printf(2, NULL, 
		"GOCR (C) 2000 Joerg Schulenburg <Joerg.Schulenburg@physik.uni-magdeburg.de>\n"
		"GOCR API Copyright (C) 2001 Bruno Barberi Gnecco <brunobg@sourceforge.net>\n"
		"Please report bugs you find, with the log, to http://jocr.sourceforge.net\n");

	_gocr_printf(3, FUNCTION, "(%d, %p)\n", argc, argv);
	
	if (loaded) {
		_gocr_printf(1, FUNCTION, "gocr already loaded\n");
		return -1;
	}
	loaded = 1;

	/* start internal data */
	_data.verbose = 3;
	_data.block_overlap = GOCR_FALSE;
	_data.no_block = GOCR_TRUE;
	_data.char_overlap = GOCR_FALSE;
	_data.char_rectangles = GOCR_TRUE;
	_data.find_all = GOCR_FALSE;
	_data.error = stderr;
	_data.print = 0;
	_data.print_image = GOCR_TRUE;
	_data.lock = 0;
	gocr_imageLoad = _gocr_imageLoad;

#ifdef MEM_DEBUG
	mtrace();
#endif
	/* call other init functions */
	if (_gocr_initModule()) {
		_gocr_printf(1, FUNCTION, "initModules()\n");
		return -1;
	}

	if (_gocr_initImage()) {
		_gocr_printf(1, FUNCTION, "initModules()\n");
		return -1;
	}

	if (_gocr_initBlock()) {
		_gocr_printf(1, FUNCTION, "initBlock()\n");
		return -1;
	}

	if (_gocr_initUnicode()) {
		_gocr_printf(1, FUNCTION, "initBlock()\n");
		return -1;
	}

	/* call external library init functions */
#if defined HAVE_PAM_H || defined HAVE_PNM_H
	pnm_init(&argc, argv);
#endif

	return 0;
}

/** 
  \brief Close library.

  This function must be called when you don't intend to use GOCR lib anymore.
*/
void gocr_finalize ( void ) {
	_gocr_printf(3, "gocr_finalize", "()\n");

	if (!loaded)
		return;

	if (currentimage)
		gocr_imageClose();

	_gocr_endModule();
	_gocr_endUnicode();
	_gocr_endBlock();
	_gocr_endImage();

	loaded = 0;
}


#undef FUNCTION
#define FUNCTION		"gocr_setAttribute"
/**
  \brief Sets an attribute value.
  
  See enum for list
  
  \param t Attribute type.
  \param value Attribute value, cast to void *.
  \sa gocr_getAttribute.
  \retval 0 OK
  \retval -1 error.
  \retval -2 Cannot change currently.
*/
int gocr_setAttribute ( gocr_AttributeType t, void *value ) {
	_gocr_printf(3, FUNCTION, "(%d, %p)\n", t, value);

	switch (t) {
	  case LIBVERSION:
		_gocr_printf(2, FUNCTION, "VERSION is read-only.\n");
		return 0;
	  case VERBOSE:
		if ((int)value < 0 || (int)value > 3) {
			_gocr_printf(2, FUNCTION,
				     "VERBOSE out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.verbose = (int)value;
		return 0;
	  case BLOCK_OVERLAP:
		if (_data.lock)
			return -2;
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "BLOCK_OVERLAP out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.block_overlap = (int)value;
		return 0;
	  case NO_BLOCK:
		if (_data.lock)
			return -2;
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "NO_BLOCK out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.no_block = (int)value;
		return 0;
	  case CHAR_OVERLAP:
		if (_data.lock)
			return -2;
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "CHAR_OVERLAP out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.char_overlap = (int)value;
		return 0;
	  case CHAR_RECTANGLES:
		if (_data.lock)
			return -2;
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "CHAR_RECTANGLES out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.char_rectangles = (int)value;
		return 0;
	  case FIND_ALL:
		if (_data.lock)
			return -2;
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "FIND_ALL out of bonds: %d\n",
				     (int)value);
			return -1;
		}
		_data.find_all = (int)value;
		return 0;
	  case ERROR_FILE:
		if (!value) {
			_gocr_printf(2, FUNCTION,
				     "OUTPUT_FILE: got NULL pointer");
			return -1;
		}
		_data.error = (FILE *) value;
		return 0;
	  case PRINT:
		if ((int)value < 0 || (int)value > 6) {
			_gocr_printf(2, FUNCTION,
				     "PRINT: value out of bounds");
			return -1;
		}
		_data.print = (int)value;
		return 0;
	  case PRINT_IMAGE:
		if ((int)value != GOCR_FALSE && (int)value != GOCR_TRUE) {
			_gocr_printf(2, FUNCTION,
				     "PRINT_IMAGE: value out of bounds");
			return -1;
		}
		_data.print_image = (int)value;
		return 0;
	  default:
		_gocr_printf(2, FUNCTION, "No such attribute %d\n", t);
		return -1;
	}
}

/**
  \brief Gets an attribute value.

  \param t Attribute type.
  \sa gocr_setAttribute.
  \return The attribute value, cast to (void *).
*/
void *gocr_getAttribute ( gocr_AttributeType t ) {
	_gocr_printf(3, "gocr_getAttribute", "(%d)\n", t);
	switch (t) {
	  case LIBVERSION:
		return (void *)VERSION;
	  case VERBOSE:
		return (void *)_data.verbose;
	  case BLOCK_OVERLAP:
		return (void *)_data.block_overlap;
	  case NO_BLOCK:
		return (void *)_data.no_block;
	  case CHAR_OVERLAP:
		return (void *)_data.char_overlap;
	  case CHAR_RECTANGLES:
		return (void *)_data.char_rectangles;
	  case FIND_ALL:
		return (void *)_data.find_all;
	  case ERROR_FILE:
		return (void *)_data.error;
	  case PRINT:
		return (void *)_data.print;
	  case PRINT_IMAGE:
		return (void *)_data.print_image;
	  default:
		_gocr_printf(2, "gocr_getAttribute", "No such attribute %d\n",
			     t);
	}
	return NULL;
}

/**
  \brief Our own printf.

  Our printf, which prints the name of the function before the message,
  both to _data.error.
 
  \param level Verbose level of the message.
  \param function The function name, may be NULL.
  \param format A printf-like format string.
  \param ... Other arguments.
*/
void _gocr_printf ( int level, char *function, char *format, ... ) {
	va_list argp;

	if ( level > _data.verbose ) 
		return;

	if ( function ) {
		fputs(function, _data.error);
		fputs(": ", _data.error);
	}
	va_start(argp, format);
	vfprintf(_data.error, format, argp);
	va_end(argp);
}

/* The following is only used for documentation, and can be disregarded. */
/*! \mainpage GOCR API doxygen documentation
 \section Development
 
 This documentation reflects the current state of GOCR API. Any part of it may
 change in anyway anytime. :)

 */
