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
#include <stdio.h>
#include <string.h>

/* 
 * global variables 
 */
gocr_Block *currentblock = NULL;

/*
 * internal data
 */
gocr_List blocklist;
static gocr_blockId blockid = 0;
static HashTable blocktypelist;
static gocr_blockType currentblocktype = 1; /* 1 because 0 would mistaken by NULL */

/*
 * _internal functions
 */
int _gocr_initBlock ( void ) {
	char *basetypes[3] = { "TEXT", "PICTURE", "MATH_EXPRESSION" };
	int i;

	hash_init(&blocktypelist, 0xFF, NULL);

	for (i = 0; i < sizeof(basetypes)/sizeof(char *); i++)
		gocr_blockTypeRegister(basetypes[i]);

	return 0;
}

void _gocr_endBlock ( void ) {
	hash_free(&blocktypelist, NULL);
}


/* 
 * API functions
 */

/* Block type functions
 */

#define FUNCTION		"gocr_blockTypeRegister"
/**
  \brief registers a new blockType. 

  Long description.

  \param name The new block type name.
  \return The blockType id (which is an integer >= 1), or -1 if error.
*/
gocr_blockType gocr_blockTypeRegister ( char *name ) {
	_gocr_printf(3, FUNCTION, "(%s): %d\n", name, currentblocktype);

	if (!name) {
		_gocr_printf(1, FUNCTION, "NULL name.\n");
		return -1;
	}

	/* insert */
	switch (hash_insert(&blocktypelist, name, (void *)currentblocktype)) {
	  case -1:
		_gocr_printf(1, FUNCTION, "Hash_insert returned -1.\n");
		return -1;
	  case -2:
		_gocr_printf(1, FUNCTION, 
				"Block type already registered. Ignoring.\n");
		return -1;
	  default:
		break;
	}

	return currentblocktype++;
}

/**
  \brief returns the blockType given its name string.

  Long description.

  \param name The block type name.
  \return The blockType id (which is an integer >= 1), or -1 if not found.
*/
gocr_blockType gocr_blockTypeGetByName ( char *name ) {
	void *ret;

	_gocr_printf(3, "gocr_blockTypeGetByName", "(%s)\n", name);

	ret = hash_data(&blocktypelist, name);
	if (ret == NULL)
		return -1;

	return (gocr_blockType) ret;
}

/**
  \brief returns the name of the block type given its id.

  Long description.

  \param t The block type id.
  \return The name of the block type or NULL if not found.
*/
const char *gocr_blockTypeGetNameByType ( gocr_blockType t ) {
	_gocr_printf(3, "gocr_blockTypeGetNameByType", "(%d)\n", t);

	return (const char *)hash_key(&blocktypelist, (void *)t);
}

#undef FUNCTION
#define FUNCTION		"gocr_blockAdd"
/**
  \brief adds a block to the block list.

  This function adds a block that you created to the list of blocks. You are
  responsible for filling the x0, x1, y0, y1 and t fields of the block
  structure, and \bonly\b those. You can pass the address of a derived block
  type to it.
  
  You can't free the block.

  \param b A pointer to the block to be added.
  \return A number less than zero if error, or the block id.
*/
gocr_blockId gocr_blockAdd ( gocr_Block * b ) {
	int i, j;

	_gocr_printf(3, FUNCTION, "(%p)\n", b);

	if (b == NULL) {
		_gocr_printf(1, FUNCTION, "NULL block\n");
		return -1;
	}

	/* checks if blocktype is registered */
	if (b->t >= currentblocktype) {
		_gocr_printf(1, FUNCTION,
			     "Block type not registered, ignoring block [%d %d]\n",
			     b->t, currentblocktype);
		return -1;
	}

	/* check boundaries */
	_gocr_fixParameters(&b->x0, &b->y0, &b->x1, &b->y1);
	if (b->x0 < 0 || b->y0 < 0 || b->x1 >= currentimage->width
	    || b->y1 >= currentimage->height) {
		_gocr_printf(1, FUNCTION, "Block is out of bounds\n");
		return -1;
	}

	/* check overlap */
	if (_data.block_overlap == 0) {
		gocr_Block *t;
		int ret = 0;

		for_each_data(&blocklist) {
			/* todo: not complete, some cases missing? */
			t = (gocr_Block *) list_get_current(&blocklist);
			if (t->x0 < b->x0 && t->x1 > b->x0 && t->y0 < b->y0
			    && t->y1 > b->y0) {
				ret = 1;
				break;
			}
			if (t->x0 < b->x1 && t->x1 > b->x1 && t->y0 < b->y1
			    && t->y1 > b->y1) {
				ret = 1;
				break;
			}
		} end_for_each(&blocklist);
		if (ret == 1) {
			_gocr_printf(2, FUNCTION, "Block overlap\n");
			return -2;
		}
	}

	/* set image */
	b->image = (gocr_Image *)malloc(sizeof(gocr_Image));
	if (!b->image) {
		_gocr_printf(1, FUNCTION, "Could not malloc.\n");
		return -1;
	}
	if (_gocr_imageSharedCopy(currentimage, b->x0, b->y0, b->x1, b->y1,
				  b->image) == -1) {
		_gocr_printf(2, FUNCTION, "Image share error\n");
		return -1;
	}

	/* fill the isblock field */
	for (i = b->y0; i <= b->y1; i++)
		for (j = b->x0; j <= b->x1; j++) {
			gocr_isblock(currentimage, j, i) = 1;
		}

	b->text = NULL;
	list_init(&b->boxlist);

	/* append to block list */
	if (list_app(&blocklist, b)) {
		_gocr_printf(2, FUNCTION, "List error\n");
		return -1;
	}

	b->id = blockid++;
	return b->id;
}

#undef FUNCTION
#define FUNCTION		"_gocr_blockInfoFill"
/**
  \brief fills the block->boxinfo structure

  Long description.

  \param b A pointer to the block to be added.
*/
void _gocr_blockInfoFill ( gocr_Block *b ) {
	gocr_Box *box;

	_gocr_printf(3, FUNCTION, "(%p)\n", b);

	b->boxinfo.min_height = 65535;
	b->boxinfo.min_width = 65535;
	b->boxinfo.max_height = 0;
	b->boxinfo.max_width = 0;
	b->boxinfo.av_height = 0;
	b->boxinfo.av_width = 0;

	for_each_data(&b->boxlist) {
		box = (gocr_Box *) list_get_current(&b->boxlist);

		if (box->y1 - box->y0 + 1 < b->boxinfo.min_height)
			b->boxinfo.min_height = box->y1 - box->y0 + 1;
		if (box->y1 - box->y0 + 1 > b->boxinfo.max_height)
			b->boxinfo.max_height = box->y1 - box->y0 + 1;
		if (box->x1 - box->x0 + 1 < b->boxinfo.min_width)
			b->boxinfo.min_width = box->x1 - box->x0 + 1;
		if (box->x1 - box->x0 + 1 > b->boxinfo.max_width)
			b->boxinfo.max_width = box->x1 - box->x0 + 1;
		b->boxinfo.av_height += (float)(box->y1 - box->y0 + 1);
		b->boxinfo.av_width += (float)(box->x1 - box->x0 + 1);
	} end_for_each(&b->boxlist);

	b->boxinfo.av_height /= (float)list_total(&b->boxlist);
	b->boxinfo.av_width /= (float)list_total(&b->boxlist);

	_gocr_printf(3, FUNCTION,
		     "height: [%d %d %f]\t"
		     "width: [%d %d %f]\n",
		     b->boxinfo.min_height, b->boxinfo.max_height,
		     b->boxinfo.av_height, b->boxinfo.min_width,
		     b->boxinfo.max_width, b->boxinfo.av_width);
}
