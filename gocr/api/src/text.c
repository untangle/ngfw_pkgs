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

/**
  \brief Returns the full word given a box

  Given a character, returns the word it's part of. This word is defined as all
  letters (see gocr_wcharIsLetter) that...
  Should underline '_' be considered a valid character?

  \param block The block.
  \param box The box.
  \sa gocr_wcharIsLetter
  \retval 0 OK
  \retval -1 error.
*/
wchar_t *gocr_textBlockGetWord ( gocr_Block *block, gocr_Box *box ) {
  wchar_t *text, *t;
  int size = 1;
  gocr_Node *begin, *end;
  gocr_Box *b;

  _gocr_debug(3, fprintf(_data.error, "gocr_textBlockGetWord(%p,%p)\n", block,
      box);)

  if ( block->t != gocr_blockTypeGetByName("TEXT") ) {
    _gocr_debug(2, fprintf(_data.error, "Not a text block.\n");)
    return NULL;
  }
  if ( !gocr_wcharIsAlpha(box->ch->c) ) {
    _gocr_debug(3, fprintf(_data.error, "%lx: Not a letter.\n", box->ch->c);)
    return NULL;
  }

  begin = list_node_from_data(&block->boxlist, box);
  end = begin->next;
  b = (gocr_Box *)begin->data;
  while ( gocr_wcharIsAlpha(b->ch->c) && begin->previous != NULL ) {
    begin = begin->previous;
    b = (gocr_Box *)begin->data;
    size++;
  }
  b = (gocr_Box *)end->data;
  while ( gocr_wcharIsAlpha(b->ch->c) && end->next != NULL ) {
    end = end->next;
    b = (gocr_Box *)end->data;
    size++;
  }

  text = (wchar_t *)malloc(size*sizeof(wchar_t));
  if ( text == NULL ) {
    _gocr_debug(1, fprintf(_data.error, "gocr_textBlockGetWord: NULL malloc %d.\n", size);)
    return NULL;
  }

  /* fill */
  for (t = text; begin != end->next; begin = begin->next ) {
    b = begin->data;
    *t++ = b->ch->c;
  }
  *t = '\0';

  return text;
}

#undef FUNCTION
#define FUNCTION		"_gocr_blockTextFill"
/**
  \brief Fills the text field

  This function sweeps the list of gocr_Boxes, filling the block->text field with
  the codes. If the block->text field was previously allocated, it's freed.

  \param b The block.
  \retval 0 OK
  \retval -1 error.
*/
int _gocr_blockTextFill ( gocr_Block *b ) {
	gocr_Box *box;
	int size;
	wchar_t *s, *t;

	_gocr_printf(3, FUNCTION, "(%p)\n", b);

	if (!b) {
		_gocr_printf(1, FUNCTION, "Null block\n");
		return -1;
	}

	if (list_empty(&b->boxlist)) {
		_gocr_printf(2, FUNCTION, "empty list\n");
		return 0;
	}

	if (b->text) {
		_gocr_printf(3, FUNCTION, "text exists, freeing it\n");
		free(b->text);
	}

	/* allocate memory. The size is a first guess. */
	size = list_total(&b->boxlist) * 1.2;
	b->text = (wchar_t *) malloc(size * sizeof(wchar_t));
	if (b->text == NULL) {
		_gocr_printf(3, FUNCTION, "NULL malloc\n");
		return -1;
	}
	b->text[0] = '\0';
	s = b->text;

	for_each_data(&b->boxlist) {
		box = (gocr_Box *) list_get_current(&b->boxlist);
		if (box == NULL) {
			_gocr_printf(2, FUNCTION, "NULL box, ignoring.\n");
			continue;
		}

		/* do we need to realloc? */
		if ((s - b->text) + (box->attributes == NULL ? 0 : 
				wcslen(box->attributes)) + 2 > size) {
			wchar_t *newtext;
			int diff;

			diff = s - b->text;
			size = (int)((float)size)*1.2 + 3;
			_gocr_printf(4, FUNCTION, "Realloc: %d\n", size);
			
			newtext =
				(wchar_t *) realloc(b->text,
						    size * sizeof(wchar_t));
			if (!newtext) {
				_gocr_printf(1, FUNCTION, "Null realloc\n");
				return -1;
			}
			b->text = newtext;
			s = b->text + diff;
		}

		/* now fill it */
		t = box->attributes;
		if (t)
			while (*t) {	/* could do with memcpy */
				*s++ = *t++;
			}

		if (box->ch)
			*s++ = box->ch->c;
		*s = '\0';
	}
	end_for_each(&b->boxlist);

	return 0;
}
