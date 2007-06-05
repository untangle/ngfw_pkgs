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

#include "gocr.h"
#include "_gocr.h"

static int window_began = 0;

/*
 * pointers to the GUI wrapper functions.
 */
static int (*_gocr_guiBeginWindow) ( wchar_t *, wchar_t ** ) = NULL;
static int (*_gocr_guiEndWindow) ( void ) = NULL;
static int (*_gocr_guiDisplayCheckButton) ( wchar_t *, wchar_t *, int * ) = NULL;
static int (*_gocr_guiDisplayImage) ( gocr_Image * ) = NULL;
static int (*_gocr_guiDisplayRadioButtons) ( wchar_t *, wchar_t **, int * ) = NULL;
static int (*_gocr_guiDisplaySpinButton) ( wchar_t *, float, float, float, float * ) = NULL;
static int (*_gocr_guiDisplayText) ( wchar_t * ) = NULL;
static int (*_gocr_guiDisplayTextField) ( wchar_t *, wchar_t ** ) = NULL;

/**
  \brief sets a GUI wrapper function.

  long description

  \param f The function type.
  \param func A pointer to the function.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiSetFunction ( gocr_GUIFunction f, void *func ) {
	if (!func)
		return -1;

	switch (f) {
	  case gocr_BeginWindow:
		_gocr_guiBeginWindow = func;
		break;
	  case gocr_EndWindow:
		_gocr_guiEndWindow = func;
		break;
	  case gocr_DisplayCheckButton:
		_gocr_guiDisplayCheckButton = func;
		break;
	  case gocr_DisplayImage:
		_gocr_guiDisplayImage = func;
		break;
	  case gocr_DisplayRadioButtons:
		_gocr_guiDisplayRadioButtons = func;
		break;
	  case gocr_DisplaySpinButton:
		_gocr_guiDisplaySpinButton = func;
		break;
	  case gocr_DisplayText:
		_gocr_guiDisplayText = func;
		break;
	  case gocr_DisplayTextField:
		_gocr_guiDisplayTextField = func;
		break;
	}
	return 0;
}


/**
  \brief starts a window.

  This functions tells the GUI to start a new window. You may set the window
  title, or pass NULL if you don't want any (the GUI will provide a default 
  one).

  The buttons parameter is a NULL terminated array of (wchar_t) strings. For
  each string a button will be inserted at the bottom of the window. 
  gocr_guiEndWindow() will return the array index of the clicked button. 
  Example: you want two buttons, "OK" or "Cancel":
  
  \code 
  wchar_t *buttons[3] = { "OK", "Cancel", NULL };
  gocr_guiBeginWindow("Title", buttons);
  ...
  switch ( gocr_guiEndWindow() ) {
	  case '0':
		  ok();
		  break;
	  case '1':
		  cancel();
		  break;
	  case '0':
		  error()
		  break;
  }
  \endcode

  If the "OK" button is clicked, gocr_guiEndWindow will return 0; if the Cancel
  button is clicked, gocr_guiEndWindow will return 1. Note that whenever a
  button is clicked the window will close.

  \param title The window title. May be NULL.
  \param buttons The buttons to display at the bottom of the window. See above.
  \sa gocr_guiEndWindow
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiBeginWindow ( wchar_t *title, wchar_t **buttons ) {
	if (window_began) {
		_gocr_printf(2, "gocr_guiBeginWindow", "Window already begun\n");
		return -1;
	}
	window_began = 1;

	if (_gocr_guiBeginWindow)
		return _gocr_guiBeginWindow(title, buttons);
	return -1;
}

/**
  \brief ends a window.

  long description. See also gocr_guiBeginWindow.

  \sa gocr_guiBeginWindow
  \return A negative number if an error happened, otherwise the index of the
  clicked button.
*/
int gocr_guiEndWindow ( void ) {
	if (!window_began) {
		_gocr_printf(2, "gocr_guiBeginWindow", "Window not begun\n");
		return -1;
	}

	window_began = 0;

	if (_gocr_guiEndWindow)
		return _gocr_guiEndWindow();
	return -1;
}

/**
  \brief adds a check button to a window.

  Adds a check button to a window. A check button is a small box that can be
  turned on or off, with a text besides it explaining what is it for.

  \param description A general description of the button. May be NULL.
  \param value The button name. Must be non-NULL.
  \param result A (non-NULL) pointer to a integer that will hold the result. 
  If the value pointed by it is not zero, the box is checked by default.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplayCheckButton ( wchar_t *description, wchar_t *value, 
		int *result ) {
	if (!value || !result) {
		_gocr_printf(2, "gocr_guiDisplayCheckButton", "NULL value or result\n");
		return -1;
	}

	if (_gocr_guiDisplayCheckButton)
		return _gocr_guiDisplayCheckButton(description, value, result);
	return -1;
}

/**
  \brief adds an image to a window.

  Adds an image to a window. The image won't be editable, and is for 
  illustration purposes only. The GUI is responsible to convert it to a 
  displayable format.

  \param image The image to display.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplayImage ( gocr_Image *image ) {
	if (!image) {
		_gocr_printf(2, "gocr_guiDisplayImage", "Null image\n");
		return -1;
	}

	if (_gocr_guiDisplayImage)
		return _gocr_guiDisplayImage(image);
	return -1;
}

/**
  \brief adds a radio button group to a window.

  Adds a radio button group to a window. A radio button group is a set of 
  options, and you can select only one of them.

  \param description A general description of the button. May be NULL.
  \param value A NULL-terminated array of (wchar_t) strings with each button
  description. Must be non-NULL.
  \param result A (non-NULL) pointer to a integer that will hold the result. 
  If the value pointed by it is non-negative, the box of that index is
  checked by default.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplayRadioButtons ( wchar_t *description, wchar_t **values, 
		int *result ) {
	if (!values || !result) {
		_gocr_printf(2, "gocr_guiDisplayRadioButtons", 
				"Null values or result\n");
		return -1;
	}

	if (_gocr_guiDisplayRadioButtons);
		return _gocr_guiDisplayRadioButtons(description, values, result);
	return -1;
}

/**
  \brief adds a spin button to a window.

  Adds a spin button to a window. A spin button is a numeric field that has
  a mininum and a maximum value, and two small icons that let the user
  increase or decrase that value by a certain step.

  This function checks if max is greater than min, and if step is less than
  (max-min).

  \param description A general description of the button. May be NULL.
  \param min The minimum allowed value.
  \param max The maximum allowed value.
  \param step The step value.
  \param result A (non-NULL) pointer to a float that will hold the result. 
  The value pointed by it is set as the default button value.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplaySpinButton ( wchar_t *description, float min, float max, 
		float step, float *result ) {
	if (!result) {
		_gocr_printf(2, "gocr_guiDisplaySpinButton", "Null result\n");
		return -1;
	}
	if (max <= min) {
		return -1;
	}
	if (step > (max-min)) {
		return -1;
	}

	if (_gocr_guiDisplaySpinButton)	
		return _gocr_guiDisplaySpinButton(description, min, max, step, result);
	return -1;
}

/**
  \brief adds an informative text to a window.

  Adds an informative text to a window. The text can't be changed by the user.

  \param text The text.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplayText ( wchar_t *text ) {
	if (!text) {
		_gocr_printf(2, "gocr_guiDisplayText", "Null text\n");
		return -1;
	}

	if (_gocr_guiDisplayText);
		return _gocr_guiDisplayText(text);
	return -1;
}

/**
  \brief adds a text field to a window.

  Adds a text field to a window. A text field is a space to let the user input
  some text of any kind.

  \param description A general description of the button. May be NULL.
  \param result A pointer to a (wchar_t) string that will hold the result. If
  NULL, the memory will be automatically allocated to hold it. Otherwise, the
  text field value is set to the string it points to.
  \sa gocr_guiBeginWindow, gocr_guiEndWindow.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_guiDisplayTextField ( wchar_t *description, wchar_t **result ) {
	if (_gocr_guiDisplayTextField)
		return _gocr_guiDisplayTextField(description, result);
	return -1;
}
