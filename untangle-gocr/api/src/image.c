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

#ifdef HAVE_PAM_H
#include <pam.h>
#endif
#if defined HAVE_PNM_H && !defined HAVE_PAM_H
#include <pnm.h>
#endif

gocr_Image *currentimage = NULL;

static gocr_List garbage;

int _gocr_initImage ( void ) {
	list_init(&garbage);
	return 0;
}

void _gocr_endImage ( void ) {
	/* todo */
}

#define FUNCTION		"datamalloc"
/* allocates memory according to the type, and do it portably */
static int datamalloc ( gocr_Image * image ) {
	int			i;
	size_t			size, psize;

	_gocr_printf(3, FUNCTION, "(%p)\n", image);
	switch (image->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		return -1;
	  case GOCR_BW:
		size = sizeof(gocr_PixelBW);
		psize = sizeof(gocr_PixelBW *);
		break;
	  case GOCR_GRAY:
		size = sizeof(gocr_PixelGray);
		psize = sizeof(gocr_PixelGray *);
		break;
	  case GOCR_COLOR:
		size = sizeof(gocr_PixelColor);
		psize = sizeof(gocr_PixelColor *);
		break;
	}

	image->data.pix = (gocr_Pixel **)malloc(image->height * psize);
	if (image->data.pix == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc\n");
		return -1;
	}
	for (i = 0; i < image->height; i++) {
		image->data.pix[i] = (gocr_Pixel *)malloc(image->width * size);
		if (!image->data.pix[i]) {
			_gocr_printf(1, FUNCTION, "NULL malloc %d\n", i);
			for (i--; i >= 0; i--) {
				free(image->data.pix[i]);
			}
			free(image->data.pix);
			return -1;
		}
		memset((void *)image->data.pix[i], 0, image->width * size);
	}
	return 0;
}


#undef FUNCTION
#define FUNCTION		"_gocr_imageSharedCopy"
/**
  \brief Fills the NEW image, sharing it with orig->data.

  Long description. Mask is copied, not shared.
  If creating a new image from a image that is already shared, the new image
  will be considered son of the parent of that image. In other words, an image
  either has sons or a parent. This is transparent to the user, and is much
  better from the developer's point of view.

  \param orig Original image.
  \param x0,y0 A vertex of the area to be copied.
  \param x1,y1 The opposite vertex.
  \param new A pointer to the new image. May be NULL.
  \sa _gocr_imageCopy, gocr_imageFree.
  \retval 0 OK
  \retval -1 error.
*/
int _gocr_imageSharedCopy ( gocr_Image *orig, int x0, int y0, int x1, int y1,
				gocr_Image *newimage ) {
	int			i;

	_gocr_printf(3, FUNCTION, "(%p, %d, %d, %d, %d, %p)\n", orig, x0, y0,
		     x1, y1, newimage);

	if (orig == NULL) {
		_gocr_printf(1, FUNCTION, "NULL pointer\n");
		return -1;
	}

	_gocr_fixParameters(&x0, &y0, &x1, &y1);
	if (x0 < 0 || x1 >= orig->width || y0 < 0 || y1 >= orig->height) {
		_gocr_printf(1, FUNCTION, "data OOB\n");
		return -1;
	}

#ifdef notnotnot /* this would require gocr_Image **newimage. */
	if (newimage == NULL) {
		newimage = (gocr_Image *) malloc(sizeof(gocr_Image));
		if (newimage == NULL) {
			_gocr_printf(1, FUNCTION, "NULL malloc\n");
			return -1;
		}
	}
	else {
		_gocr_printf(2, FUNCTION, "got a non NULL structure; memory waste may occur\n");
	}
#endif

	newimage->filename = NULL;
	newimage->width = x1 - x0 + 1;
	newimage->height = y1 - y0 + 1;
	newimage->type = orig->type;
	switch (newimage->type) {
	  case GOCR_NONE:
	  case GOCR_OTHER:
		_gocr_printf(1, FUNCTION, "type %d\n", newimage->type);
		return -1;	/* shouldn't occur */
	  case GOCR_BW:
		newimage->data.pix = malloc(newimage->height * sizeof(gocr_PixelBW *));
		break;
	  case GOCR_GRAY:
		newimage->data.pix = malloc(newimage->height * sizeof(gocr_PixelGray *));
		break;
	  case GOCR_COLOR:
		newimage->data.pix = malloc(newimage->height * sizeof(gocr_PixelColor *));
		break;
	}
	if (newimage->data.pix == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc 2\n");
		return -1;
	}
	if (orig->mask) {
		newimage->mask = malloc(((newimage->height * newimage->width) >> 3) + 1);
		if (newimage->mask == NULL) {
			_gocr_printf(1, FUNCTION, "NULL malloc 3\n");
			return -1;
		}
		memcpy(newimage->mask, orig->mask, ((newimage->height*newimage->width)>>3) + 1);
	}
	else 
		newimage->mask = NULL;
		
	for (i = 0; i < newimage->height; i++)
		newimage->data.pix[i] = orig->data.pix[i + y0] + 
				x0 * _gocr_imagePixelSize(newimage);

	if (orig->parent) {
		newimage->parent = orig->parent;
		newimage->sons = 0;
	}
	else {
		newimage->parent = orig;
		newimage->sons = 0;
	}
	newimage->parent->sons++;
	return 0;
}

#undef FUNCTION
#define FUNCTION		"_gocr_imageCopy"
/**
  \brief fill newimage image, copying the data to a new memory location

  Long description. Copies mask.

  \param orig Original image.
  \param x0,y0 A vertex of the area to be copied.
  \param x1,y1 The opposite vertex.
  \param newimage A pointer to the new image. May not be NULL.
  \sa _gocr_imageSharedCopy
  \retval 0 OK
  \retval -1 error.
*/
int _gocr_imageCopy ( gocr_Image *orig, int x0, int y0, int x1, int y1,
		    gocr_Image *newimage ) {
	int			i;

	_gocr_printf(3, FUNCTION, "(%p, %d, %d, %d, %d, %p)\n", orig, x0, y0, 
			x1, y1, newimage);

	if (orig == NULL) {
		_gocr_printf(1, FUNCTION, "NULL pointer\n");
		return -1;
	}

	_gocr_fixParameters(&x0, &y0, &x1, &y1);

	if (x0 < 0 || x1 >= orig->width || y0 < 0 || y1 >= orig->height) {
		_gocr_printf(1, FUNCTION, "data OOB\n");
		return -1;
	}

#ifdef notnotnot /* this would require gocr_Image **newimage. */
	if (newimage == NULL) {
		newimage = (gocr_Image *)malloc(sizeof(gocr_Image));
		if (newimage == NULL) {
			_gocr_printf(1, FUNCTION, "NULL malloc\n");
			return -1;
		}
	}
#endif
	newimage->filename = NULL;
	newimage->width = x1 - x0 + 1;
	newimage->height = y1 - y0 + 1;
	newimage->type = orig->type;
	newimage->sons = 0;
	newimage->parent = NULL;
	if (datamalloc(newimage) == -1) {
		_gocr_printf(1, FUNCTION, "datamalloc\n");
		return -1;
	}

	if (orig->mask) {
		newimage->mask = malloc(((newimage->height * newimage->width) >> 3) + 1);
		if (newimage->mask == NULL) {
			_gocr_printf(1, FUNCTION, "NULL malloc 3\n");
			return -1;
		}
		memcpy(newimage->mask, orig->mask, ((newimage->height * newimage->width) >> 3) + 1);
	}
	else 
		newimage->mask = NULL;

	for (i = 0; i < newimage->height; i++)
		memcpy(newimage->data.pix[i], orig->data.pix[i + y0] +
			       x0 * _gocr_imagePixelSize(newimage), newimage->width);
	return 0;
}

/**
  \brief Fix rectangle parameters.

  This function fix the parameters that define a rectangle, making sure that
  (x0, y0) is the top-left vertex, and (x1,y1) is the bottom right one.

  \param x0,y0 Pointers to the first vertex coordinates.
  \param x1,y1 Pointers to the opposite vertex coordinates.
*/
void _gocr_fixParameters ( int *x0, int *y0, int *x1, int *y1 ) {
	if (*x0 <= *x1 && *y0 <= *y1)	/* OK */
		return;

	if (*x0 > *x1 && *y0 > *y1) {	/* then swap the pairs */
		int i;
		i = *x0;		*x0 = *x1;		*x1 = i;
		i = *y0;		*y0 = *y1;		*y1 = i;
		return;
	}

	if (*x0 > *x1 && *y0 <= *y1) {	/* correct is (x1,y0), (x0,y1) */
		int i;
		i = *x0;		*x0 = *x1;		*x1 = i;
		return;
	}

	if (*x0 <= *x1 && *y0 > *y1) {	/* correct is (x0,y1), (x1,y0) */
		int i;
		i = *y0;		*y0 = *y1;		*y1 = i;
		return;
	}
}

/*
    feel free to expand this list of usable converting programs
    Note 1: the last field must be NULL.
    Note 2: "smaller" extensions must come later: ".pnm.gz" must come
       before ".pnm".
    todo: make this thing dynamic, and let users add new conversors.
 */
static const char *xlist[] = {
	".pnm.gz",    "gzip -cd",
	".pbm.gz",    "gzip -cd",
	".pgm.gz",    "gzip -cd",
	".ppm.gz",    "gzip -cd",
	".pnm.bz2",   "bzip2 -cd",
	".pbm.bz2",   "bzip2 -cd",
	".pgm.bz2",   "bzip2 -cd",
	".ppm.bz2",   "bzip2 -cd",
	".jpg",       "djpeg -gray -pnm",
	".jpeg",      "djpeg -gray -pnm",
	".gif",       "giftopnm",
	".bmp",       "bmptoppm",
	".tiff",      "tifftopnm",
	".png",       "pngtopnm",
	NULL
};

/* return a pointer to command converting file to pnm or NULL */
static const char *testsuffix ( const char *name ) {
	int i;

	for (i = 0; xlist[i] != NULL; i += 2) {
		if (strstr(name, xlist[i]) != NULL)
			return xlist[i + 1];
	}
	return NULL;
}

#undef FUNCTION
#define FUNCTION		"_gocr_imageLoad"
/**
  \brief Loads an image.

  This function loads an image to the currentimage structure.

  \param filename The file name. 
  \param data Image type;
  \retval 0 OK
  \retval -1 error.
*/
int _gocr_imageLoad ( const char *filename, void *data ) {
	const char 		*command;
	FILE 			*fp;
	int 			row, col;
	gocr_ImageType 		type = (gocr_ImageType) data;
#ifdef HAVE_PAM_H
	struct pam 		inpam;
	tuple 			*tuplerow;
#endif

	_gocr_printf(3, FUNCTION, "(%s, %d)\n", filename, type);

	/* open file; test if conversion is needed. */
	command = testsuffix(filename);
	if (!command) {
		fp = fopen(filename, "rb");
		if (!fp) {
			_gocr_printf(1, FUNCTION,
				     "File %s couldn't be opened\n",
				     filename);
			return -1;
		}
	}
	else {
		char *buf = (char *)malloc(
					   (strlen(command) +
					    strlen(filename) +
					    2) * sizeof(char));

		sprintf(buf, "%s %s", buf, filename);
		_gocr_printf(3, FUNCTION, "# popen( %s )\n", buf);
#if defined(__USE_POSIX2)
		fp = popen(buf, "r");
#else
		_gocr_printf(0, FUNCTION,
			     "Sorry, you must compile with __USE_POSIX2 to use pipes\n"
			     "Cannot open this file format without pipes\n");
#endif
		if (!fp)
			_gocr_printf(1, FUNCTION, "opening pipe %s\n", buf);

		free(buf);
	}

	/* do we have an image? If so, close it first */
	if (currentimage)
		gocr_imageClose();

	/* allocate memory */
	currentimage = (gocr_Image *) malloc(sizeof(gocr_Image));
	if (currentimage == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc\n");
		fclose(fp);
		return -1;
	}

	/* check type to convert */
	if (type != GOCR_NONE)
		currentimage->type = type;
	else { /* set type here or datamalloc will return -1 */
	}

#ifdef HAVE_PAM_H
	pnm_readpaminit(fp, &inpam, sizeof(inpam));

	/* allocate memory for the image data */
	currentimage->width = inpam.width;
	currentimage->height = inpam.height;
	if (datamalloc(currentimage) == -1) {
		free(currentimage);
		fclose(fp);
		return -1;
	}

	/* and fill it */
	if (inpam.depth == 1
	    && strcmp(inpam.tuple_type, PAM_PBM_TUPLETYPE) == 0) {
		/* we have a PBM (Black and white) */
		_gocr_printf(3, FUNCTION, "PBM format detected.\n");

		tuplerow = pnm_allocpamrow(&inpam);
		for (row = 0; row < inpam.height; row++) {
			pnm_readpamrow(&inpam, tuplerow);
			for (col = 0; col < inpam.width; col++)
				gocr_imagePixelSetBW(currentimage, col, row,
						     (tuplerow[col][0] ==
						      PAM_PBM_BLACK ?
						      GOCR_BLACK :
						      GOCR_WHITE));
		}
		pnm_freepamrow(tuplerow);
	}
	else if (inpam.depth == 1
		 && strcmp(inpam.tuple_type, PAM_PGM_TUPLETYPE) == 0) {
		/* we have a PGM (gray) */
		_gocr_printf(3, FUNCTION, "PGM format detected.\n");

		if (type == GOCR_NONE)
			currentimage->type = GOCR_GRAY;

		tuplerow = pnm_allocpamrow(&inpam);
		for (row = 0; row < inpam.height; row++) {
			pnm_readpamrow(&inpam, tuplerow);
			for (col = 0; col < inpam.width; col++)
				gocr_imagePixelSetGray(currentimage, col, row,
						       tuplerow[row][0]);
		}
		pnm_freepamrow(tuplerow);
	}
	else if (inpam.depth == 3
		 && strcmp(inpam.tuple_type, PAM_PPM_TUPLETYPE) == 0) {
		/* we have a PPM (color) */
		_gocr_printf(3, FUNCTION, "PPM format detected.\n");

/* to be tested */
		if (type == GOCR_NONE)
			currentimage->type = GOCR_COLOR;

		tuplerow = pnm_allocpamrow(&inpam);
		for (col = 0; col < inpam.height; col++) {
			pnm_readpamrow(&inpam, tuplerow);
			for (row = 0; row < inpam.width; row++)
				gocr_imagePixelSetColor(currentimage, col, row,
						       (unsigned char *)tuplerow[row]);
		}
		pnm_freepamrow(tuplerow);
		goto error;
	}
	else {
		_gocr_printf(1, FUNCTION, "Format not recognized.\n");
		goto error;
	}
#endif
#if defined HAVE_PNM_H && !defined HAVE_PAM_H
	_gocr_printf(0,
		     FUNCTION,
		     "PNM not coded yet. Get a newer NetPBM with pam functions.\n");
#endif
	currentimage->filename = strdup(filename);
	currentimage->mask = NULL;
	currentimage->sons = 0;
	currentimage->parent = NULL;
	
	fclose(fp);

	_gocr_thresholdGrayToBW(currentimage);
/*	_gocr_thresholdColorToGray(); */

	return 0;

      error:			/* free, close, and return */
	fclose(fp);
	for (row = 0; row < currentimage->height; row++)
		free(currentimage->data.pix[row]);
	free(currentimage->data.pix);
	free(currentimage);
	return -1;
}

/**
  \brief Closes an image.

  This function closes the image in currentimage, freeing all memory associated
  with it (except block structures).

*/
void gocr_imageClose ( void ) {
	gocr_Block	*block;
	gocr_Box	*box;

	for_each_data(&blocklist) {
		block = (gocr_Block *)list_get_current(&blocklist);
		for_each_data(&block->boxlist) {
			box = (gocr_Box *)list_get_current(&block->boxlist);
			gocr_imageFree(box->image); 
			for_each_data(&box->possible) {
				gocr_Char *c = (gocr_Char *)list_get_current(&box->possible);
				free(c);
			} end_for_each(&box->possible);
			list_free(&box->possible);
			free(box);
		} end_for_each(&block->boxlist);
		list_free(&block->boxlist);
		gocr_imageFree(block->image);
/*		free(block); */
	} end_for_each(&blocklist);
	list_free(&blocklist);

	gocr_imageFree(currentimage);
	currentimage = NULL;
}

#undef FUNCTION
#define FUNCTION			"gocr_imageFree"
/**
  \brief Closes an image.

  This function closes the image, freeing all memory. Images that have 
  "children", i.e., the "parent" of shared images may not be instantaneously
  freed, and the responsability of freeing it is handled to the internal
  garbage collector.

  \param image A pointer to the image structure.
*/
void gocr_imageFree ( gocr_Image *image ) {
	_gocr_printf(3, FUNCTION, "(%p)\n", image);

	if (image == NULL)
		return;

	if (image->sons == 0) { /* no children, free it */
		if (image->parent) { /* is shared */
			image->parent->sons--;

			/* garbage collection */
			if (image->parent->sons == 0) {
				gocr_Image *par;
				for_each_data(&garbage) {
					par = (gocr_Image *)list_get_current(&garbage);
					if (par == image->parent)
						break;
				} end_for_each(&garbage);
				if (par == image->parent) {
					list_del(&garbage, par);
					gocr_imageFree(par);
				}
			}
			free(image->data.pix);
		}
		else { /* it is not shared */
			if (image->data.pix) {
				int i;
	
				for (i = 0; i < image->height; i++)
					if (image->data.pix[i])
						free(image->data.pix[i]);
				free(image->data.pix);
			}
		}
		if (image->filename)
			free(image->filename);
		if (image->mask)
			free(image->mask);
		free(image);
	}
	else { /* has sons */
		gocr_Image *new;
					
		new = (gocr_Image *)malloc(sizeof(gocr_Image));
		if (!new) {
			_gocr_printf(2, FUNCTION, 
				"Could not duplicate, using the old image. This may lead to future problems.\n");
			new = image;
		}
		else {
			memcpy(new, image, sizeof(gocr_Image));
			free(image);
		}
		list_app(&garbage, new);
	}
	return;
}


#undef FUNCTION
#define FUNCTION			"_gocr_imageWrite"

/**
  \brief Writes image to a file.

  Long description.

  \param image A pointer to the image.
  \param filename The output file name.
  \param data If 1, print blocks and boxes frames
  \sa gocr_imageWriteWithData
  \retval 0 OK
  \retval -1 error.
*/
int _gocr_imageWrite ( gocr_Image *image, char *filename, char data ) {
	FILE *fp;
	int i, j;
#ifdef HAVE_PAM_H
	struct pam outpam;
#endif

	_gocr_printf(3, FUNCTION, "(%p, %s, %d)\n", image, filename, data);

	if (image == NULL) {
		_gocr_printf(1, FUNCTION, "NULL image\n");
		return -1;
	}

	/* open the file */
	if (filename == NULL) {
		filename = image->filename;
		if (filename == NULL) {
			_gocr_printf(1, FUNCTION, "NULL filename\n");
			return -1;
		}
	}

	fp = fopen(filename, "w");
	if (fp == NULL) {
		_gocr_printf(1, FUNCTION, "File open error\n");
		return -1;
	}

	if (data == 1) { /* process boxes and blocks */
		gocr_Block *block;
		gocr_Box *box;
		for_each_data(&blocklist) {
			block = (gocr_Block *) list_get_current(&blocklist);
			for (i = block->x0; i <= block->x1; i++) {
				_gocr_private1(image, i, block->y0) = 1;
				_gocr_private1(image, i, block->y1) = 1;
			}
			for (i = block->y0; i <= block->y1; i++) {
				_gocr_private1(image, block->x0, i) = 1;
				_gocr_private1(image, block->x1, i) = 1;
			}

			for_each_data(&block->boxlist) {
				box = (gocr_Box *)list_get_current(&block->boxlist);
				for (i = box->x0; i <= box->x1; i++) {
					_gocr_private2(block->image, i, 
							box->y0) = 1;
					_gocr_private2(block->image, i, 
							box->y1) = 1;
				}
				for (i = box->y0; i <= box->y1; i++) {
					_gocr_private2(block->image, 
							box->x0, i) = 1;
					_gocr_private2(block->image, 
							box->x1, i) = 1;
				}
			}
			end_for_each(&block->boxlist);
		}
		end_for_each(&blocklist);
	}

#ifdef HAVE_PAM_H		/* DO WE need to write the pam AND the pnm? */
	/* fill the pam structure */
	outpam.file = fp;
	outpam.size = sizeof(struct pam);
	outpam.len = sizeof(struct pam);
	outpam.height = image->height;
	outpam.width = image->width;

	if (data == 0) {	/* output .pbm */
		outpam.format = PBM_FORMAT;
		outpam.depth = 1;
		outpam.maxval = 1;
		strcpy(outpam.tuple_type, PAM_PBM_TUPLETYPE);
	}
	else {			/* output ppm */
		outpam.format = PPM_FORMAT;
		outpam.depth = 3;
		outpam.maxval = 255;
		strcpy(outpam.tuple_type, PAM_PGM_TUPLETYPE);
	}
	pnm_writepaminit(&outpam);
	if (data == 1) {
		tuple *tuplerow;

		tuplerow = pnm_allocpamrow(&outpam);
		for (i = 0; i < outpam.height; i++) {
			for (j = 0; j < outpam.width; j++) {
				if (gocr_imagePixelGetBW(image, j, i) == GOCR_BLACK)/* bit */
					tuplerow[j][0] = tuplerow[j][1] =
						tuplerow[j][2] = 0;
				else
					tuplerow[j][0] = tuplerow[j][1] =
						tuplerow[j][2] =
						outpam.maxval;

				if (_gocr_private1(image, j, i)) {	/* block */
					tuplerow[j][0] = outpam.maxval;
					tuplerow[j][1] = tuplerow[j][2] = 0;
					_gocr_private1(image, j, i) = 0;
				}

				if (_gocr_private2(image, j, i)) {	/* box */
					if (!
					    (tuplerow[j][0] == outpam.maxval
					     && tuplerow[j][1] == 0)) {
						/* clean */
						tuplerow[j][0] =
							tuplerow[j][1] = 0;
					}
					tuplerow[j][2] = outpam.maxval;
					_gocr_private2(image, j, i) = 0;
				}
			}
			pnm_writepamrow(&outpam, tuplerow);
		}
		pnm_freepamrow(tuplerow);
	}
#endif /* HAVE_PAM_H */

#if defined HAVE_PNM_H && !defined HAVE_PAM_H && defined notbynow
	if (data == 0) {	/* output .pbm */
		bit *bitrow;

		pbm_writepbminit(fp, image->height, image->width, 0);
		bitrow = pbm_allocrow(image->height);
		for (i = 0; i < image->height; i++) {
			for (j = 0; j < image->width; j++)
				bitrow[j] =
					(image->data[i][j].value ==
					 GOCR_BLACK ? PBM_BLACK : PBM_WHITE);
			pbm_writepbmrow(fp, bitrow, image->width, 0);
		}
		pbm_freerow(bitrow);
	}
	else {			/* output .ppm */
		int maxval = 255;
		pixel *pixelrow;

		/* pre-process blocks and characters, adding the frames in the private*
		   fields. There are better, faster ways to handle. */

		ppm_writeppminit(fp, image->height, image->width,
				 PPM_MAXMAXVAL, 0);
		pixelrow = ppm_allocrow(image->width);

		for (i = 0; i < image->height; i++) {	/* for each line */
			for (j = 0; j < image->width; j++) {
				if (image->data[i][j].value == GOCR_BLACK)	/* bit */
					PPM_ASSIGN(pixelrow[j], 0, 0, 0);
				else
					PPM_ASSIGN(pixelrow[j], 255, 255,
						   255);

				if (image->data[i][j].private1) {	/* block */
					PPM_ASSIGN(pixelrow[j], 255, 0, 0);
					image->data[i][j].private1 = 0;
				}
				if (image->data[i][j].private2) {	/* box */
					PPM_ASSIGN(pixelrow[j], 0, 0, 255);
					image->data[i][j].private2 = 0;
				}
			}
			ppm_writeppmrow(fp, pixelrow, image->width,
					PPM_MAXMAXVAL, 0);
		}
		ppm_freerow(pixelrow);
	}
#endif

	fclose(fp);
	return 0;
}


/**
  \brief Writes image to a file.

  Long description.

  \param image A pointer to the image.
  \param filename The output file name.
  \sa gocr_imageWriteWithData
  \retval 0 OK
  \retval -1 error.
*/
int gocr_imageWrite ( gocr_Image *image, char *filename ) {
	return _gocr_imageWrite( image, filename, 0 );
}

/**
  \brief Writes the whole image to a file with extra data.

  Outputs the image to a file, in the PPM raw format, drawing boxes around:
    - boxes, in red
    - characters, in blue

  \param filename The output file name.
  \bugs Do not call this function in the middle of a gocr_charBegin/gocr_charEnd
  or gocr_charSplitBegin/gocr_charSplitEnd pair; unpredictable behaviour will
  occur.
  This function may be slow if you have many boxes and blocks.
  \sa gocr_imageWriteData
  \retval 0 OK
  \retval -1 error.
*/
int gocr_mainImageWriteWithData ( char *filename ) {
	return _gocr_imageWrite( currentimage, filename, 1 );
}
