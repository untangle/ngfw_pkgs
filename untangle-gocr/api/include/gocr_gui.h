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

#ifndef _GOCR_GUI_H
#define _GOCR_GUI_H

#ifndef _GOCR_MODULE_H
# error "Do not call gocr_gui.h directly; call gocr_module.h instead."
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*! \file gocr_gui.h
  \brief This is the gui header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/** @name Module GUI functions
  */
/*@{*/
extern int gocr_guiBeginWindow ( wchar_t *title, wchar_t **buttons );
extern int gocr_guiEndWindow ( void );
extern int gocr_guiDisplayCheckButton ( wchar_t *description, wchar_t *value,
 	       int *result );
extern int gocr_guiDisplayImage ( gocr_Image *image );
extern int gocr_guiDisplayRadioButtons ( wchar_t *description, wchar_t **values,
 	       int *result );
extern int gocr_guiDisplaySpinButton ( wchar_t *description, float min, 
		float max, float step, float *result );
extern int gocr_guiDisplayText ( wchar_t *text );
extern int gocr_guiDisplayTextField ( wchar_t *description, wchar_t **result );

/*@}*/
#ifdef __cplusplus
}
#endif

#endif
