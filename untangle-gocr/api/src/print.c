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

static int returnflag = 0;

#define FUNCTION		"gocr_printArea"
/**
  \brief prints an image.

  This function prints an image to the file specified by the ERROR_FILE
  attribute, formatted according to the PRINT attribute:
 
      - \b 0: only data bit (. = WHITE, * = BLACK)
      - \b 1: marked bits (mark1 + 2*mark2 + 4*mark3)
      - \b 2: data and marked bits: if white, a...h; if black, A..H
      - \b 3: only isblock bit (. = is not block, * = is block)
      - \b 4: only ischar bit (. = is not char, * = is char)
      - \b 5: complete byte, in hexadecimal
      - \b 6: complete byte, in ASCII.

  Refer to the PostScript documentation for a more detailed description.

  \param new A pointer to the image.
  \param x0,y0 A vertex of the area to be copied.
  \param x1,y1 The opposite vertex.
  \sa gocr_setAttribute, gocr_getAttribute, PS documentation.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_printArea ( gocr_Image * image, int x0, int y0, int x1, int y1 ) {
	int			i, j;

	_gocr_printf(3, FUNCTION, "(%p, %d, %d, %d, %d)\n", image, x0,
			    y0, x1, y1);

	if (image == NULL || image->data.pix == NULL) {
		_gocr_printf(1,	FUNCTION, "NULL image or image data\n");
		return -1;
	}

	_gocr_fixParameters(&x0, &y0, &x1, &y1);

	for (i = y0; i <= y1; i++) {
		if (_data.print == 6) {	/* just dump it */
			fwrite(image->data.pix[i], _gocr_imagePixelSize(image),
			       x0 - x1 + 1, _data.error);
		}
		else for (j = x0; j <= x1; j++)
			switch (_data.print) {
			  case 0:	/* only data bit */
				fputc(gocr_imagePixelGetBW(image, j, i) ==
				       GOCR_BLACK ? '*' : '.',
				      _data.error);
				break;
			  case 1:	/* marked bits */
				fputc('0' + gocr_pixelGetMark1(image, j, i) +
				      2 * gocr_pixelGetMark2(image, j, i) +
				      4 * gocr_pixelGetMark3(image, j, i),
				      _data.error);
				break;
			  case 2:	/* data+marked */
				fputc(
				      (gocr_imagePixelGetBW(image, j, i) ==
				       GOCR_BLACK ? 'A' : 'a') +
				      gocr_pixelGetMark1(image, j, i) +
				      2 * gocr_pixelGetMark2(image, j, i) +
				      4 * gocr_pixelGetMark3(image, j, i),
				      _data.error);
				break;
			  case 3:	/* block bit */
				fputc(
				      (gocr_isblock(image, j, i) ==
				       GOCR_BLACK ? '*' : '.'),
				      _data.error);
				break;
			  case 4:	/* recognized bit */
				fputc(
				      (gocr_ischar(image, j, i) ==
				       GOCR_BLACK ? '*' : '.'),
				      _data.error);
				break;
			  case 5:	/* all, hexa */
/*				fprintf(_data.error, "%x",
					(int)*((unsigned char *) 
					       &image->data[i][j])); */
				break;
			}
		if (!returnflag)	/* this is used by gocr_printBox2 */
			fputc('\n', _data.error);
	}
	return 0;
}


#undef FUNCTION
#define FUNCTION			"gocr_printBlock"
/**
  \brief prints a block.
  
  This function prints a block to the file specified by the ERROR_FILE
  attribute. If PRINT_IMAGE attribute is 1 (true), the image of the block will
  be printed too.

  \param b A pointer to the block.
  \sa gocr_setAttribute, gocr_getAttribute, gocr_printImage.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_printBlock ( gocr_Block *b ) {
	_gocr_printf(3, FUNCTION, "gocr_printBlock(%p)\n", b);

	if (b == NULL) {
		_gocr_printf(1, FUNCTION,
			     "NULL gocr_Block\n");
		return -1;
	}

/* future: let the user provide his own print block function too */
	fprintf(_data.error, "Block: x0:%d, y0:%d, x1:%d, y1:%d; type %s\n"
		"Info: height[%d %d %f], width [%d %d %f]\n",
		b->x0, b->y0, b->x1, b->y1, gocr_blockTypeGetNameByType(b->t),
		b->boxinfo.min_height, b->boxinfo.max_height,
		b->boxinfo.av_height, b->boxinfo.min_width,
		b->boxinfo.max_width, b->boxinfo.av_width);

	if (_data.print_image)
		return gocr_printArea(b->image, 0, 0, b->image->width - 1,
				      b->image->height - 1);

	return 0;
}

#undef FUNCTION
#define FUNCTION			"gocr_printBox"    
/**
  \brief prints a box.
  
  This function prints a box to the file specified by the ERROR_FILE
  attribute. If PRINT_IMAGE attribute is 1 (true), the image of the box will
  be printed too.

  \param b A pointer to the box.
  \sa gocr_setAttribute, gocr_getAttribute, gocr_printImage.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_printBox ( gocr_Box * b ) {
	_gocr_printf(3, FUNCTION, "(%p)\n", b);

	if (b == NULL) {
		_gocr_printf(1, FUNCTION, "NULL gocr_Box\n");
		return -1;
	}

	fprintf(_data.error,
		"Box: x0:%d, y0:%d, x1:%d, y1:%d; c:%lx ac:%lx mod:%lx\n",
		b->x0, b->y0, b->x1, b->y1, b->c, b->ac, b->modifier);

	if (_data.print_image)
		return gocr_printArea(currentblock->image, b->x0, b->y0,
				      b->x1, b->y1);

	return 0;
}

#undef FUNCTION
#define FUNCTION			"gocr_printBox2"    

/**
  \brief prints two boxes.
  
  This function prints two boxes side by side, to the file specified by the 
  ERROR_FILE attribute. If PRINT_IMAGE attribute is 1 (true), the image of the
  boxes will be printed too.

  \param b A pointer to the box.
  \sa gocr_setAttribute, gocr_getAttribute, gocr_printImage.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_printBox2 ( gocr_Box *b1, gocr_Box *b2 ) {
	int xmax, xend, i, j;

	_gocr_printf(3, FUNCTION, "(%p, %p)\n", b1, b2);

	if (b1 == NULL || b2 == NULL) {
		_gocr_printf(1, FUNCTION, "NULL gocr_Box\n");
		return -1;
	}
#if 0
	if (b1->image == NULL || b2->image == NULL) {
		_gocr_printf(1, FUNCTION,
			     "NULL gocr_Box image at gocr_printBox2\n");
		return -1;
	}
#endif

	/* these are used below, to know which box ends first */
	if (b1->x1 - b1->x0 < b2->x1 - b2->x0) {
		xmax = b1->x1 - b1->x0 + 1;
		xend = b2->x1 - b2->x0 + 1;
	}
	else {
		xmax = b2->x1 - b2->x0 + 1;
		xend = b1->x1 - b1->x0 + 1;
	}

	fprintf(_data.error,
		"Box1: x0:%d, y0:%d, x1:%d, y1:%d; c:%lx ac:%lx mod:%lx\n",
		b1->x0, b1->y0, b1->x1, b1->y1, b1->c, b1->ac, b1->modifier);
	fprintf(_data.error,
		"Box2: x0:%d, y0:%d, x1:%d, y1:%d; c:%lx ac:%lx mod:%lx\n",
		b2->x0, b2->y0, b2->x1, b2->y1, b2->c, b2->ac, b2->modifier);

	returnflag++;		/* so printArea doesn't print \n */
	/* print */
	if (_data.print_image) {
		for (i = 0; i < xmax; i++) {
			gocr_printArea(currentblock->image, b1->x0 + i,
				       b1->y0, b1->x0 + i, b1->y1);
			fputs("  ", _data.error);
			gocr_printArea(currentblock->image, b2->x0 + i,
				       b2->y0, b2->x0 + i, b2->y1);
			fputs("\n", _data.error);
		}
	}
	/* one of the characters ended first; print the rest of the other */
	for (; i < xend; i++) {
		if (b1->x1 - b1->x0 < b2->x1 - b2->x0) {	/* pad with spaces */
			for (j = b1->y0; j <= b1->y1; j++)
				fputc(' ', _data.error);
			fputs("  ", _data.error);
			gocr_printArea(currentblock->image, b2->x0 + i,
				       b2->y0, b2->x0 + i, b2->y1);
		}
		else {
			gocr_printArea(currentblock->image, b1->x0 + i,
				       b1->y0, b1->x0 + i, b1->y1);
		}
		fputs("\n", _data.error);
	}
	returnflag = 0; /* clean flag */

	return 0;
}

