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
 

#ifndef _GOCR_IMAGE_H 
#define _GOCR_IMAGE_H 

#ifndef _GOCR_MODULE_H
# error "Do not call gocr_gui.h directly; call gocr_module.h instead."
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*! \file gocr_image.h
  \brief This is the image header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/** @name Image
  */
/*@{*/
/**
  \brief Black pixel value.
  \sa gocr_Pixel.
*/
#define GOCR_BLACK			0
/**
  \brief White pixel value.
  \sa gocr_Pixel.
*/
#define GOCR_WHITE			1


/**
  \brief Image type values.
*/
enum gocr_imagetype {
	GOCR_NONE, 			/**< No type. */
	GOCR_BW, 			/**< Black and white. */
	GOCR_GRAY, 			/**< Grayscale. */
	GOCR_COLOR,			/**< Color. */
	GOCR_OTHER 			/**< Other (user-defined). */
};
/**
  \brief Typedef encapsulation.
*/
typedef enum gocr_imagetype gocr_ImageType;

/**
 \brief This is the pixel structure.
 
 Long description.

*/
struct gocr_pixelbw {
	unsigned char	value : 1;	/**< pixel value. */
	unsigned char	mark1 : 1;	/**< user defined marker 1. */
	unsigned char	mark2 : 1;	/**< user defined marker 2. */
	unsigned char	mark3 : 1;	/**< user defined marker 3. */
	unsigned char	isblock : 1;	/**< is part of a block? */
	unsigned char	ischar : 1;	/**< is part of a character? */
	unsigned char	private1 : 1;	/**< reserved, used internally (find.c). */
	unsigned char	private2 : 1;	/**< reserved, used internally */
};
/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_pixelbw gocr_PixelBW;

struct gocr_pixelgray {
	unsigned char	pad : 1;	/**< pad bit. */
	unsigned char	mark1 : 1;	/**< user defined marker 1. */
	unsigned char	mark2 : 1;	/**< user defined marker 2. */
	unsigned char	mark3 : 1;	/**< user defined marker 3. */
	unsigned char	isblock : 1;	/**< is part of a block? */
	unsigned char	ischar : 1;	/**< is part of a character? */
	unsigned char	private1 : 1;	/**< reserved, used internally (find.c). */
	unsigned char	private2 : 1;	/**< reserved, used internally */
	
	unsigned char 	value;
};
typedef struct gocr_pixelgray gocr_PixelGray;

struct gocr_pixelcolor {
	unsigned char	pad : 1;	/**< pad bit. */
	unsigned char	mark1 : 1;	/**< user defined marker 1. */
	unsigned char	mark2 : 1;	/**< user defined marker 2. */
	unsigned char	mark3 : 1;	/**< user defined marker 3. */
	unsigned char	isblock : 1;	/**< is part of a block? */
	unsigned char	ischar : 1;	/**< is part of a character? */
	unsigned char	private1 : 1;	/**< reserved, used internally (find.c). */
	unsigned char	private2 : 1;	/**< reserved, used internally */

	unsigned char 	value[3];
};
typedef struct gocr_pixelcolor gocr_PixelColor;


/**
 \brief This is the pixel wrapper data structure.
 
 It should work with any pixel data structure.

*/
struct gocr_pixel {
	unsigned char	pad : 1;	/**< pad bit. */
	unsigned char	mark1 : 1;	/**< user defined marker 1. */
	unsigned char	mark2 : 1;	/**< user defined marker 2. */
	unsigned char	mark3 : 1;	/**< user defined marker 3. */
	unsigned char	isblock : 1;	/**< is part of a block? */
	unsigned char	ischar : 1;	/**< is part of a character? */
	unsigned char	private1 : 1;	/**< reserved, used internally (find.c). */
	unsigned char	private2 : 1;	/**< reserved, used internally */

	char		value[0];
};
typedef struct gocr_pixel gocr_Pixel;

/**
 \brief This is the image structure.
 
 Long description.

*/
struct gocr_image {
	char		*filename;	/**< file name; may be NULL. */
	int		width, height;	/**< size. */
	gocr_ImageType	type;		/**< image type. */

	union {
		gocr_Pixel	**pix;	/**< opaque type */
		gocr_PixelBW	**bw;	/**< bw pixel */
		gocr_PixelGray	**gray; /**< gray pixel */
		gocr_PixelColor	**color;/**< color pixel */
	} data;

/* you are unlikely to change these below. Future: hide them */
	unsigned char	*mask;
	int		threshold;	/**< image threshold, for gray->bw conversion. */
	int		sons;		/**< number of shared images */
	struct gocr_image *parent;	/**< if shared, the parent */
};

/**
  \brief Typedef encapsulation.
*/
typedef struct gocr_image gocr_Image;

/* image.c */
extern void gocr_imageFree ( gocr_Image *image );
extern int gocr_imageWrite ( gocr_Image *image, char *filename );
extern int gocr_mainImageWriteWithData ( char *filename );

/* pixel.c */
extern inline int gocr_pixelGetMark1 ( gocr_Image *image, int x, int y );
extern inline int gocr_pixelSetMark1 ( gocr_Image *image, int x, int y, char value );
extern inline int gocr_pixelGetMark2 ( gocr_Image *image, int x, int y );
extern inline int gocr_pixelSetMark2 ( gocr_Image *image, int x, int y, char value );
extern inline int gocr_pixelGetMark3 ( gocr_Image *image, int x, int y );
extern inline int gocr_pixelSetMark3 ( gocr_Image *image, int x, int y, char value );

#define gocr_isblock(image, x, y) \
 ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->isblock
#define gocr_ischar(image, x, y) \
 ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->ischar


extern void gocr_imagePixelSetBW ( gocr_Image *image, int x, int y, 
		unsigned char data );
extern unsigned char gocr_imagePixelGetBW ( gocr_Image *image, int x, int y );
extern void gocr_imagePixelSetGray ( gocr_Image *image, int x, int y,
		unsigned char data );
extern unsigned char gocr_imagePixelGetGray ( gocr_Image *image, int x, int y );
extern void gocr_imagePixelSetColor ( gocr_Image *image, int x, int y,
		unsigned char data[3] );
extern unsigned char *gocr_imagePixelGetColor ( gocr_Image *image, int x, int y );

/*@}*/

#ifdef _GOCR_INTERNAL_H /*ok, this #ifdef sucks, but is a quick hack */

extern int 	_gocr_imageLoad		( const char *filename, void *data );
extern size_t	_gocr_imagePixelSize	( gocr_Image *image );
extern int 	_gocr_thresholdGrayToBW ( gocr_Image *image );

#define _gocr_private1(image, x, y) \
 ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->private1
#define _gocr_private2(image, x, y) \
 ((gocr_Pixel *)((image)->data.pix[y]+(x)*_gocr_imagePixelSize(image)))->private2
#define _gocr_maskGet(img, x, y) \
	!!(img->mask[(((y)*(img)->width+(x))>>3)]&(((y)*img->width+(x))%8))
#define _gocr_maskSet(img, x, y, v) \
	img->mask[(((y)*(img)->width+(x))>>3)] &= ((v)&(1<<((y)*img->width+(x))%8))
#endif

/**
  \brief A pointer to the current image.
  This variable holds the image being processed right now, and can be freely
  accessed by the programmer.
  \sa gocr_imageLoad, gocr_imageClose, gocr_Image.
*/
extern gocr_Image	*currentimage;

#ifdef __cplusplus
}
#endif

#endif
