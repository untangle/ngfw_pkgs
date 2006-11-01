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
#include <string.h>

#define boundary_error()  \
	x < 0 || x >= image->width || y < 0 || y >= image->height

/*
  The following algorithm was sent by Ryan Dibble <dibbler@umich.edu>.
 
  The algorithm is very simple but works well.
 
  Compare the grayscale histogram with a mass density diagram:
  I think the algorithm is a kind of
  divide a body into two parts in a way that the mass 
  centers have the largest distance from each other,
  the function is weighted in a way that same masses have a advantage */
int _gocr_thresholdGrayToBW ( gocr_Image *image ) {
	int thresholdValue;	// value we will threshold at
	int ihist[256];		// image histogram

	int row, col, i;		// various counters
	int n, n1, n2, gmin, gmax;
	unsigned char c;
	double m1, m2, sum, csum, fmax, sb;
	gocr_PixelGray p;

	_gocr_printf(3, "_gocr_thresholdGrayToBW", "(%p)\n", image);

	
	if (image->type != GOCR_GRAY) {
		return -1;
	}
	memset(&p, 0, sizeof(gocr_PixelGray));

	/* zero out histogram ... */
	memset(ihist, 0, sizeof(ihist));

	gmin = 255;
	gmax = 0;
	/* generate the histogram */
	for (row = 1; row < image->height - 1; row++) {
		for (col = 1; col < image->width - 1; col++) {
			c = gocr_imagePixelGetGray(image, col, row);
			ihist[c]++;
			if (c > gmax)
				gmax = c;
			if (c < gmin)
				gmin = c;
		}
	}

	/* set up everything */
	sum = csum = 0.0;
	n = 0;

	for (i = 0; i <= 255; i++) {
		sum += (double)i *(double)ihist[i];	/* x*f(x) mass moment */
		n += ihist[i];	/*  f(x)    mass      */
	}

	if (!n) {
		/* if n has no value we have problems... */
		_gocr_printf(1, "otsu", "NOT NORMAL thresholdValue = %d\n",
				    thresholdValue);
		image->threshold = 128;
		return -1;
	}

	/* do the otsu global thresholding method */

	fmax = -1.0;
	n1 = 0;
	for (i = 0; i < 255; i++) {
		n1 += ihist[i];
		if (!n1) {
			continue;
		}
		n2 = n - n1;
		if (n2 == 0) {
			break;
		}
		csum += (double)i *ihist[i];
		m1 = csum / n1;
		m2 = (sum - csum) / n2;
		sb = (double)n1 *(double)n2 *(m1 - m2) * (m1 - m2);
		/* bbg: note: can be optimized. */
		if (sb > fmax) {
			fmax = sb;
			thresholdValue = i;
		}
	}

	/* at this point we have our thresholding value */
	image->threshold = thresholdValue;

#ifdef obsolete_todo_rewrite
	/* actually performs the thresholding of the image...
	   comment it out if you only want to know what value to threshold at... */
	for (row = 0; row < image->height; row++)
		for (col = 0; col < image->width; col++)
			image->data[row][col].value =
				(data[row][col] >
				 thresholdValue ? GOCR_WHITE : GOCR_BLACK);
#endif

	return 0;
}



/**
  \brief Gets image pixel mark 1.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \retval 0 unset.
  \retval 1 set.
  \retval -1 error.
*/
inline int gocr_pixelGetMark1 ( gocr_Image *image, int x, int y ) {
	if ( boundary_error() )
		return -1;
	return ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark1;
}

/**
  \brief Sets image pixel mark 1.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param value New value.
  \retval 0 OK.
  \retval -1 error.
*/
inline int gocr_pixelSetMark1 ( gocr_Image *image, int x, int y, char value ) {
	if ( boundary_error() )
		return -1;
	((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark1 = !!value;
	/* and the above line should go to the Obfuscated C Contest! 
	The idea is: image->data.pix[y][x].mark1 = (value == 0 ? 0 : 1) */
	return 0;
}

/**
  \brief Gets image pixel mark 2.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \retval 0 unset.
  \retval 1 set.
  \retval -1 error.
*/
inline int gocr_pixelGetMark2 ( gocr_Image *image, int x, int y ) {
	if ( boundary_error() )
		return -1;
	return ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark2;
}

/**
  \brief Sets image pixel mark 2.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param value New value.
  \retval 0 OK.
  \retval -1 error.
*/
inline int gocr_pixelSetMark2 ( gocr_Image *image, int x, int y, char value ) {
	if ( boundary_error() )
		return -1;
	((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark2 = !!value;
	return 0;
}

/**
  \brief Gets image pixel mark 3.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \retval 0 unset.
  \retval 1 set.
  \retval -1 error.
*/
inline int gocr_pixelGetMark3 ( gocr_Image *image, int x, int y ) {
	if ( boundary_error() )
		return -1;
	return ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark3;
}

/**
  \brief Sets image pixel mark 3.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param value New value.
  \retval 0 OK.
  \retval -1 error.
*/
inline int gocr_pixelSetMark3 ( gocr_Image *image, int x, int y, char value ) {
	if ( boundary_error() )
		return -1;
	((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->mark3 = !!value;
	return 0;
}


/**
  \brief Returns the size of a image pixel.

  Long description.

  \param image Pointer to the image.
  \return The size, in bytes.
*/
size_t _gocr_imagePixelSize ( gocr_Image *image ) {
	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return -1;
	  case GOCR_BW:
		return sizeof(gocr_PixelBW);
	  case GOCR_GRAY:
		return sizeof(gocr_PixelGray);
	  case GOCR_COLOR:
		return sizeof(gocr_PixelColor);
	}
	return -1;
}

/**
  \brief Gets the value of a image pixel in BW.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \return The pixel value, converted to BW.
  \sa gocr_imagePixelSetBW, gocr_imagePixelSetGray, gocr_imagePixelSetColor,
      gocr_imagePixelGetGray, gocr_imagePixelGetColor.
*/
unsigned char gocr_imagePixelGetBW ( gocr_Image *image, int x, int y ) {
	if (boundary_error())
		return 0;

	if (image->mask) 
		if (!_gocr_maskGet(image, x, y))
			return 0;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return 0;
	  case GOCR_BW:
		return image->data.bw[y][x].value;
	  case GOCR_GRAY:
		return (image->data.gray[y][x].value 
				< image->threshold ? 0 : 1 ); 

	  case GOCR_COLOR:
/*		return (image->data.color[x][y]).value[0]... >
		p->value[0] = (data == 0 ? 0 : 255);
		p->value[1] = (data == 0 ? 0 : 255);
		p->value[2] = (data == 0 ? 0 : 255); 
		return ; */
		return 0;
	}
	return 0;
}

/**
  \brief Sets the value of a image pixel in BW.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param data New value.
  \sa gocr_imagePixelSetGray, gocr_imagePixelSetColor, gocr_imagePixelGetBW,
      gocr_imagePixelGetGray, gocr_imagePixelGetColor.
*/
void gocr_imagePixelSetBW ( gocr_Image *image, int x, int y, unsigned char data ) {
	if ( boundary_error() )
		return;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return;
	  case GOCR_BW:
		image->data.bw[y][x].value = !!data;
		return;
	  case GOCR_GRAY:
		image->data.gray[y][x].value = (data == 0 ? 0 : 255);
		return;
	  case GOCR_COLOR:
		image->data.color[y][x].value[0] = (data == 0 ? 0 : 255);
		image->data.color[y][x].value[1] = (data == 0 ? 0 : 255);
		image->data.color[y][x].value[2] = (data == 0 ? 0 : 255);
		return;
	}
}
	
/**
  \brief Gets the value of a image pixel in grayscate.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \return The pixel value, converted to BW.
  \sa gocr_imagePixelSetBW, gocr_imagePixelSetGray, gocr_imagePixelSetColor,
      gocr_imagePixelGetBW, gocr_imagePixelGetColor.
*/
unsigned char gocr_imagePixelGetGray ( gocr_Image *image, int x, int y ) {
	if ( boundary_error() )
		return 0;

	if (image->mask) 
		if (!_gocr_maskGet(image, x, y))
			return 0;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return 0;
	  case GOCR_BW:
		return (image->data.bw[y][x].value == 0 ? 0 : 255);
	  case GOCR_GRAY:
		return image->data.gray[y][x].value;
	  case GOCR_COLOR:
/*		return image->data.color[y][x].value[0]
		image->data.color[y][x].value[1] 
		image->data.color[y][x].value[2] */
	}
	return 0;
}

/**
  \brief Sets the value of a image pixel in grayscale.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param data New value.
  \sa gocr_imagePixelSetBW, gocr_imagePixelSetColor, gocr_imagePixelGetBW,
      gocr_imagePixelGetGray, gocr_imagePixelGetColor.
*/
void gocr_imagePixelSetGray ( gocr_Image *image, int x, int y, 
		unsigned char data ) {
	if ( boundary_error() )
		return;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return;
	  case GOCR_BW:
		image->data.bw[y][x].value = (data < image->threshold ? 0 : 1);
		return;
	  case GOCR_GRAY:
		image->data.gray[y][x].value = data;
		return;
	  case GOCR_COLOR:
		image->data.color[y][x].value[0] = data;
		image->data.color[y][x].value[1] = data;
		image->data.color[y][x].value[2] = data;
		return;
	}
}

/**
  \brief Gets the value of a image pixel in color.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \return The pixel value, converted to BW.
  \sa gocr_imagePixelSetBW, gocr_imagePixelSetGray, gocr_imagePixelSetColor,
      gocr_imagePixelGetBW, gocr_imagePixelGetGray.
*/
unsigned char *gocr_imagePixelGetColor ( gocr_Image *image, int x, int y ) {
	static unsigned char ret[3] = { 0, 0, 0 };

	if ( boundary_error() )
		return ret;

	if (image->mask) 
		if (!_gocr_maskGet(image, x, y))
			return ret;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return ret;
	  case GOCR_BW:
		if (image->data.bw[y][x].value == 1)
			ret[0] = ret[1] = ret[2] = 255;
		return ret;
	  case GOCR_GRAY:
		ret[0] = ret[1] = ret[2] = image->data.gray[y][x].value;
		return ret;
	  case GOCR_COLOR:
		return image->data.color[y][x].value;
	}
	return ret;
}

/**
  \brief Sets the value of a image pixel in color.

  Long description.

  \param image Pointer to the image.
  \param x x coordinate.
  \param y y coordinate.
  \param data New value.
  \sa gocr_imagePixelSetBW, gocr_imagePixelSetGray, gocr_imagePixelGetBW,
      gocr_imagePixelGetGray, gocr_imagePixelGetColor.
*/
void gocr_imagePixelSetColor ( gocr_Image *image, int x, int y, 
		unsigned char data[3] ) {
	if ( boundary_error() )
		return;

	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return;
	  case GOCR_BW:
/*		image->data.bw[y][x].value = 
(data[0] data[1] data[2] < 128 ? 0 : 1); */
		return;
	  case GOCR_GRAY:
/*		image->data.color[y][x].value = (data[0] data[1] data[2]); */
		return;
	  case GOCR_COLOR:
		image->data.color[y][x].value[0] = data[0];
		image->data.color[y][x].value[1] = data[1];
		image->data.color[y][x].value[2] = data[2];
		return;
	}
}

