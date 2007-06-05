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
#include <string.h>

gocr_Box *currentbox;

static int began = 0;

static gocr_Image *workimage = NULL;
static gocr_Box *oldbox = NULL;


#define NEWCHAR   1
#define SPLITCHAR 2

/* idea: charBegin inits a structure;
   charset* sets bits in the image, and update the frame;
   charEnd creates a new image, sized frame, all white, and fills with the
       pixels set by charset*, and calls the charRecognizer module (how?
       by a signal? directly by runModule? 
*/
#define FUNCTION		"gocr_charBegin"
/**
  \brief inits a new character structure.

  Long description.

  \attention Do not change the value of the CHAR_OVERLAP attribute between a
  gocr_charBegin/End pair, or unpredictable behaviour may occur.
  \sa gocr_charEnd, gocr_charSetAttribute, gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charBegin ( void ) {
	_gocr_printf(3, FUNCTION, "()\n");

	if (began) {
		_gocr_printf(1, FUNCTION, "Character already begun\n");
		return -1;
	}

	began = NEWCHAR;

	/* we are working in the block */
	workimage = currentblock->image;

	currentbox = (gocr_Box *) malloc(sizeof(gocr_Box));
	if (!currentbox) {
		_gocr_printf(1, FUNCTION, "charBegin: not enough memory\n");
		return -1;
	}

	/* set the boundaries in such a way that they are not valid and will be updated */
	currentbox->x0 = workimage->width;
	currentbox->y0 = workimage->height;
	currentbox->x1 = -1;
	currentbox->y1 = -1;
	currentbox->attributes = NULL;
	currentbox->image = NULL;
	currentbox->attributes = NULL;
	currentbox->ch = NULL;
	list_init(&currentbox->possible);

	/* deprecated fields */
	currentbox->c = currentbox->ac = currentbox->modifier = UNICODE_NULL;

	return 0;
}

#undef FUNCTION
#define FUNCTION		"gocr_charEnd"
/**
  \brief closes a new character structure.

  Long description; adds to the character list.

  \sa gocr_charBegin.
  \retval 0 OK
  \retval -1 error.
*/
/* todo: receive an argument that sets if it is a rectangle or uses mask? Is it
a good idea? */
int gocr_charEnd ( void ) {
	int i, j;

	_gocr_printf(3, FUNCTION, "()\n");

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");
		return -1;
	}
	if (began == SPLITCHAR) {
		_gocr_printf(1, FUNCTION, 
				"ERROR: should've called gocr_charSplitEnd\n");
		return -1;
	}

	began = 0;

/* idea: create a bitmask instead of a copy of the image. This way, we cut
memory use to 1/8, and yet keep all information */

	currentbox->image = (gocr_Image *)malloc(sizeof(gocr_Image));
	if (currentbox->image == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc\n");
		return -1;
	}
	/* we have to create a 2nd image to allow the pixel by pixel selection */
	if (_gocr_imageSharedCopy(currentblock->image, currentbox->x0, 
			currentbox->y0, currentbox->x1, currentbox->y1, 
			currentbox->image) != 0) {
		_gocr_printf(1, FUNCTION, "Could not copy image\n");
		return -1;
	}

	if (!_data.char_rectangles) { /* use mask */
		currentbox->image->mask = malloc(((currentbox->image->height * 
			currentbox->image->width) >> 3) + 1);
		if (!currentbox->image->mask) {
			_gocr_printf(1, FUNCTION, "Could not create mask\n");
			return -1;
		}
		memset(currentbox->image->mask, 0xFF, ((currentbox->image->height * 
			currentbox->image->width) >> 3) + 1);
	}
	else { /* use only rect coords */
	}

/* todo: _data.char_overlap. It should be detected in the Set* functions, but
is missing in SetAllNear. If set, use the ischar field to hold the mask
information. */
	for (i = currentbox->y0; i <= currentbox->y1; i++)
		for (j = currentbox->x0; j <= currentbox->x1; j++) {
			if (_gocr_private1(workimage, j, i) == 1) {
				_gocr_private1(workimage, j, i) = 0;
				gocr_ischar(workimage, j, i) = 1;
				/* mask is set */
			}
			else if (!_data.char_rectangles)
				_gocr_maskSet(workimage, j - currentbox->x0,
						i - currentbox->y0, 0);
		}

	if (_data.find_all == GOCR_FALSE) {
#if 0
		gocr_runModule(charRecognizer, box);
		gocr_runModule(contextCorrection, box);
		gocr_imageFree(box->image);
		free(box->image);
		box->image = NULL;
#endif
	}
	list_app(&currentblock->boxlist, currentbox);

	workimage = NULL;

	return 0;
}

#ifdef UNSTABLE_NOTDONE
#undef FUNCTION
#define FUNCTION		"gocr_charSplitBegin"
/**
  \brief splits an existing character in two.

  Long description.
  Any attributes go to the new box, which is put before the old one in the
  list. FLAG TO DO IT?

  \param box The gocr_Box to be split.
  \attention Do not change the value of the CHAR_OVERLAP attribute between a
  gocr_charBegin/End pair, or unpredictable behaviour may occur.
  \sa gocr_charSplitEnd, gocr_charAbort, gocr_charSetAttribute, 
  gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charSplitBegin ( gocr_Box *box ) {
	_gocr_printf(3, FUNCTION, "%p\n", box);

	if (began) {
		_gocr_printf(1, FUNCTION, "Character already begun\n");
		return -1;
	}

	began = SPLITCHAR;

	/* we are working in the current box */
	workimage = box->image;	// or something

	currentbox = (gocr_Box *) malloc(sizeof(gocr_Box));
	if (!currentbox) {
		_gocr_printf(1, FUNCTION, "charBegin: not enough memory\n");
		return -1;
	}

	/* set the boundaries in such a way that they are not valid and will be updated */
	currentbox->x0 = workimage->width;
	currentbox->y0 = workimage->height;
	currentbox->x1 = -1;
	currentbox->y1 = -1;

	currentbox->attributes = NULL;

	list_init(&currentbox->possible);
	currentbox->ch = NULL;

	/* deprecated fields */
	currentbox->c = currentbox->ac = currentbox->modifier = UNICODE_NULL;

	return 0;
}

#undef FUNCTION
#define FUNCTION		"gocr_charSplitEnd"
/**
  \brief closes a splitting character structure.

  Long description; adds to the character list before the original one, 
  attributes are moved to new one.

  \param position If 0, inserts before; if 1, inserts after.
  \sa gocr_charSplitBegin, gocr_charAbort.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charSplitEnd ( int position ) {
	int i, j;
	int newx0, newx1, newy0, newy1;

	_gocr_printf(3, FUNCTION, "(%d)\n", position);

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");
		return -1;
	}
	if (began == NEWCHAR) {
		_gocr_printf(1, FUNCTION, "should've called gocr_charEnd\n");
		return -1;
	}

	began = 0;

	 /*TODO*/
		/* refit and realloc oldbox */
	for (newy0 = oldbox->y0; newy0 <= oldbox->y1; newy0++)
		for (i = oldbox->x0; i <= oldbox->x1; i++)
			if (oldbox->image.data[][i].value == 1 &&
			    oldbox->image.data[][i].private1 == 0)
				break;
	// etc

	/* clean bits that are not longer part of it (private1) */
	for (i = 0; i < oldbox->y; i++)
		for (j = 0; j < oldbox->x; j++)
/* something along      if ( oldbox->image.data[i][j].private1 ) {
      	oldbox->image.data[i][j].private1 = 0;
      	oldbox->image.data[i][j].private1 = 0;
      } */

			if (position == 0) {	/* inserts before */
				/*TODO move attributes */
				list_ins(&currentblock->boxlist, currentbox,
					 oldbox);
			}
			else {
				void *v =
					list_next(&currentblock->boxlist,
						  oldbox);

				/* need to mvoe attributes? */

				list_ins(&currentblock->boxlist, currentbox,
					 v);
			}
	workimage = NULL;

	return 0;
}
#endif // unstable_notdone

/**
  \brief aborts a begun character.

  This function aborts a character begun using gocr_charBegin or 
  gocr_charSplitBegin. All changes done by the gocr_charSet* functions since 
  the last call to gocr_charBegin or gocr_charSplitBegin are undone.

  \sa gocr_charBegin, gocr_charEnd, gocr_charSplitBegin, gocr_charSplitEnd.
*/
void gocr_charAbort ( void ) {
	_gocr_printf(3, "gocr_charAbort", "()\n");

	if (!began)
		return;

	began = 0;
	oldbox = NULL;

	if (currentbox) {
		if (currentbox->attributes)
			free(currentbox->attributes);
		free(currentbox);
	}

	currentbox = NULL;
}


#undef FUNCTION
#define FUNCTION		"gocr_charSetAllNearPixels"

/**
  \brief set/unset all 4- or 8-connected pixels (fill).

  This function selects or unselects all pixels that are 4- or 8- connected
  to the argument pixel.

  \param action Either GOCR_SET or GOCR_UNSET.
  \param x The x coordinate of the pixel.
  \param y The y coordinate of the pixel.
  \param connect Either 4 or 8. If any other value is passed, assumes 4.
  \bugs This function had selection of characters in mind. If you use it to
  select backgrounds, very complex images, etc, it may fill its internal stack 
  and segfault before the job is done.
  \sa gocr_charBegin, gocr_charEnd, gocr_charSetAttribute, gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
#define push(x,y)     { n++; stack[n][0] = x; stack[n][1] = y; }
#define pop(x,y)      { x = stack[n][0]; y = stack[n][1]; n--; }

int gocr_charSetAllNearPixels ( int action, int x, int y, int connect ) {
	char			fg, bg;
	int 			stack[256][2];	/* guess 256 is enough */
	int 			i, j, n = -1;

	_gocr_printf(3, FUNCTION, "(%d, %d, %d, %d)\n",
		     action, x, y, connect);

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");
		return -1;
	}

	if (x < 0 || x >= workimage->width || y < 0 || y >= workimage->height) {
		_gocr_printf(1, FUNCTION, "Pixel out of bounds.\n");
		return -1;
	}

	if (action != GOCR_SET && action != GOCR_UNSET) {
		_gocr_printf(1, FUNCTION,
			     "Action is neither SET or UNSET.\n");
		return -1;
	}

	if (connect != 4 && connect != 8) {
		_gocr_printf(3, FUNCTION, "Assuming 4 connected.\n");
		connect = 4;
	}

	/* bg is the color we want to select */
	bg = gocr_imagePixelGetBW(workimage, x, y);
	fg = !bg;

	/* algorithm description: scan each line, adding pixels above and below 
	   for recursion to the stack. */
	push(x, y);

	while (n >= 0) {
		int below = 0, above = 0;

		pop(i, j);

		/* check y boundaries */
		if (currentbox->y0 > j)
			currentbox->y0 = j;
		if (currentbox->y1 < j)
			currentbox->y1 = j;

		/* start by going to the leftmost pixel on the line. This wastes 
		   some time, since the loop sweeps the same interval again, so an 
		   optimization would be handy. */
		while (i > 0 && gocr_imagePixelGetBW(workimage, i - 1, j) == bg)
			i--;

		if (currentbox->x0 > i)
			currentbox->x0 = i;

		/* 8-connected requires checking some extra pixels. If we are at &, 
		   check the pixels marked with +:
		   **+....
		   ...&***
		   **+....
		 */
		if (connect == 8) {
			if (i > 0) {
				if (j > 0 &&
				    gocr_imagePixelGetBW(workimage, i - 1,
							 j - 1) == bg &&
				    gocr_imagePixelGetBW(workimage, i,
							 j - 1) != bg &&
				    _gocr_private1(workimage, i - 1,
						   j - 1) != action ) 
					push(i - 1, j - 1);
				if (j < workimage->height - 1 &&
				    gocr_imagePixelGetBW(workimage, i - 1,
							 j + 1) == bg &&
				    gocr_imagePixelGetBW(workimage, i,
							 j + 1) != bg &&
				    _gocr_private1(workimage, i - 1,
						   j + 1) != action ) 
					push(i - 1, j + 1);
			}
		}

		/* sweep the line */
		for (; gocr_imagePixelGetBW(workimage, i, j) == bg && 
				i < workimage->width; i++) {
			/* check if the pixel above should go to stack */
			if (j > 0 && above == 0 &&
			    gocr_imagePixelGetBW(workimage, i, j - 1) == bg &&
			    _gocr_private1(workimage, i, j - 1) != action) {
				push(i, j - 1);
				above++;
			}
			else if (j > 0 && above == 1 &&
				 gocr_imagePixelGetBW(workimage, i,
						      j - 1) == fg) {
				above--;
			}
			/* if the below should */
			if (j < workimage->height - 1 && below == 0 &&
			    gocr_imagePixelGetBW(workimage, i, j + 1) == bg &&
			    _gocr_private1(workimage, i, j + 1) != action) {
				push(i, j + 1);
				below++;
			}
			else if (j < workimage->height - 1 && below == 1 &&
				 gocr_imagePixelGetBW(workimage, i,
						      j + 1) == fg) {
				below--;
			}

			_gocr_private1(workimage, i, j) = action;

		}
		i--;		/* last pixel of the line */

		/* check the other 2 possible 8-connections, now on the end of the line. */
		if (connect == 8) {
			if (i < workimage->width - 1) {
				if (j > 0 &&
				    gocr_imagePixelGetBW(workimage, i + 1,
							 j - 1) == bg &&
				    gocr_imagePixelGetBW(workimage, i,
							 j - 1) != bg &&
				    _gocr_private1(workimage, i + 1,
							 j - 1) != action) 
					push(i + 1, j - 1);

				if (j < workimage->height - 1 &&
				    gocr_imagePixelGetBW(workimage, i + 1,
							 j + 1) == bg &&
				    gocr_imagePixelGetBW(workimage, i,
							 j + 1) != bg &&
				    _gocr_private1(workimage, i + 1, 
							 j + 1) != action) 
					push(i + 1, j + 1);
			}
		}
		/* and update last x boundary */
		if (currentbox->x1 < i)
			currentbox->x1 = i;
	}
	return 0;
}

#undef FUNCTION
#define FUNCTION		"gocr_charSetAttribute"
/**
  \brief set/unset a character attribute 

  Long description. attribute  must be registered. Function prototype not
  stable yet. Currently (deliberatedly) not working. See gocr_boxAttributeSet.

  \param action Either GOCR_SET or GOCR_UNSET.
  \param name Attribute name.
  \param ... Data.
  \sa gocr_charBegin, gocr_charEnd, gocr_charSetAllNearPixels, gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charSetAttribute ( int action, char *name, ... ) {
	_gocr_printf(3, FUNCTION, "gocr_charSetAttribute(%d, %s)\n",
		     action, name);

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");
		return -1;
	}

	if (action != GOCR_SET && action != GOCR_UNSET) {
		_gocr_printf(1, FUNCTION, "Action is neither SET or UNSET.\n");
		return -1;
	}

	_gocr_printf(0, FUNCTION, "use gocr_boxSetAttribute instead \n");
	return -1;
//  return gocr_boxAttributeSet(currentbox, action, name, ...);
}


#undef FUNCTION
#define FUNCTION		"gocr_charSetPixel"
/**
  \brief set/unset a pixel.

  This functions selects or unselects a pixel. 

  \param action Either GOCR_SET or GOCR_UNSET.
  \param x The x coordinate of the pixel.
  \param y The y coordinate of the pixel.
  \sa gocr_charBegin, gocr_charEnd, gocr_charSetAttribute, gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charSetPixel ( int action, int x, int y ) {
	_gocr_printf(3, FUNCTION, "(%d, %d, %d)\n", action, x, y);

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");

		return -1;
	}

	/* check boundaries */
	if (x < 0 || x >= workimage->width || y < 0 || y >= workimage->height) {
		_gocr_printf(1, FUNCTION, "Pixel out of bounds.\n");
		return -1;
	}

	if (action != GOCR_SET && action != GOCR_UNSET) {
		_gocr_printf(1, FUNCTION, "Action is neither SET or UNSET.\n");
		return -1;
	}

	/* update new boundaries */
	if (action == 1) {	/* selecting */
		if (x < currentbox->x0)
			currentbox->x0 = x;
		if (x > currentbox->x1)
			currentbox->x1 = x;
		if (y < currentbox->y0)
			currentbox->y0 = y;
		if (y > currentbox->y1)
			currentbox->y1 = y;
	}
	else {			/* unselecting, we may have to shrink */
		int i;
		if (x == currentbox->x0) {
			for (; currentbox->x0 <= currentbox->x1; currentbox->x0++) {
				for (i = currentbox->y0; i <= currentbox->y1; i++)
					if (_gocr_private1(workimage,
					    currentbox->x0, i) == 1)
						goto x0end;	/* gotos are easier 
						here */
			}
		      x0end:
		}
		else if (x == currentbox->x1) {
			for (; currentbox->x1 >= currentbox->x1; currentbox->x1--)
				for (i = currentbox->y0; i <= currentbox->y1; i++)
					if (_gocr_private1(workimage, 
					    currentbox->x1, i) == 1)
						goto x1end;
		      x1end:
		}
		if (x == currentbox->y0) {
			for (; currentbox->y0 <= currentbox->y1; currentbox->y0++)
				for (i = currentbox->x0; i <= currentbox->x1; i++)
					if (_gocr_private1(workimage, 
					    i, currentbox->y0) == 1)
						goto y0end;
		      y0end:
		}
		else if (x == currentbox->y1) {
			for (; currentbox->y1 >= currentbox->y1; currentbox->y1--)
				for (i = currentbox->x0; i <= currentbox->x1; i++)
					if (_gocr_private1(workimage,
					    i, currentbox->y1) == 1)
						goto y1end;
		      y1end:
		}
	}

	if (!(_data.char_overlap == 1 && gocr_ischar(workimage, x, y) == 1 &&
	      began == NEWCHAR))
		_gocr_private1(workimage, x, y) = action;

	return 0;
}

#undef FUNCTION
#define FUNCTION		"gocr_charSetRect"
/**
  \brief set/unset all pixels in a rectangle.

  This function allows you to select or unselect all pixels in a rectangle
  defined by two opposite vertices. The rectangle must be entirely in the image.
  The boundaries of the rectangle are considered to be part of it: a rectangle
  defined by (1,1), (1,1) vertices is the point (1,1).

  If the CHAR_OVERLAP flag is false, and you are creating a new character
  (i.e., used gocr_charBegin and not gocr_charSplitBegin) it automatically 
  selects only those pixels which are not already part of another character.

  \param action Either GOCR_SET or GOCR_UNSET.
  \param x0,y0 A vertex (x0, y0) of the rectangle.
  \param x1,y1 The opposite vertex (x1, y1).
  \sa gocr_charBegin, gocr_charEnd, gocr_charSetAttribute, gocr_charSetPixel, gocr_charSetRect.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charSetRect ( int action, int x0, int y0, int x1, int y1 ) {
	int i, j;
	_gocr_printf(3, FUNCTION, "(%d, %d, %d, %d, %d)\n",
		     action, x0, y0, x1, y1);

	if (!began) {
		_gocr_printf(1, FUNCTION, "Character not begun\n");
		return -1;
	}

	if (action != GOCR_SET && action != GOCR_UNSET) {
		_gocr_printf(1, FUNCTION,
			     "Action is neither SET or UNSET.\n");
		return -1;
	}

	/* check boundaries */
	if (x0 < 0 || x0 >= workimage->width ||
	    x1 < 0 || x1 >= workimage->width || 
	    y0 < 0 || y0 >= workimage->height || 
	    y1 < 0 || y1 >= workimage->height) {
		_gocr_printf(1, FUNCTION, "Rectangle out of bounds.\n");
		return -1;
	}

	/* should reverse x and y if needed */
	_gocr_fixParameters(&x0, &y0, &x1, &y1);

	/* update new boundaries */
	if (action == 1) {	/* selecting */
		if (x0 < currentbox->x0)
			currentbox->x0 = x0;
		if (x1 > currentbox->x1)
			currentbox->x1 = x1;
		if (y0 < currentbox->y0)
			currentbox->y0 = y0;
		if (y1 > currentbox->y1)
			currentbox->y1 = y1;
	}
	else {			/* unselecting */
		/* we are only interested in the intersection of the rectangle and the box */
		if (x0 < currentbox->x0)
			x0 = currentbox->x0;
		if (x1 < currentbox->x1)
			x1 = currentbox->x1;
		if (y0 < currentbox->y0)
			y0 = currentbox->y0;
		if (y1 < currentbox->y1)
			y1 = currentbox->y1;

		/* it the entire area is selected, take care of it */
		if (x0 == currentbox->x0 && x1 == currentbox->x1 &&
		    y0 == currentbox->y0 && y1 == currentbox->y1) {
			currentbox->x0 = workimage->width;
			currentbox->y0 = workimage->height;
			currentbox->x1 = -1;
			currentbox->y1 = -1;
		}
		else {		/* only part of it */
			/* we may be able to shrink the box, so test it */
			if (x0 == currentbox->x0 && y0 == currentbox->y0
			    && y1 == currentbox->y1)
				currentbox->x0 = x1 + 1;
			if (x1 == currentbox->x1 && y0 == currentbox->y0
			    && y1 == currentbox->y1)
				currentbox->x0 = x0 - 1;
			if (y0 == currentbox->y0 && x0 == currentbox->x0
			    && x1 == currentbox->x1)
				currentbox->y0 = y1 + 1;
			if (y0 == currentbox->y0 && x0 == currentbox->x0
			    && x1 == currentbox->x1)
				currentbox->y0 = y0 - 1;
		}
	}

	/* and now do the work, man */
	for (i = y0; i <= y1; i++)
		for (j = x0; j <= x1; j++)
			if (!(_data.char_overlap == 1
			     && gocr_ischar(currentimage, j, i) == 1
			     && began == NEWCHAR)) 
				_gocr_private1(currentimage, j, i) = action;

	return 0;
}
