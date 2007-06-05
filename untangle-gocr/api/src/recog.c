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

/* Should we use hash tables or lists in the struct gocr_Char? */


#define FUNCTION		"gocr_boxCharSet"
/**
  \brief Sets a possible character to a box

  Long description. 
 
  \param w The character.
  \param prob The probability (0.0<=p<=1.0)
  \retval 0 OK
  \retval -1 error.
*/
int gocr_boxCharSet ( gocr_Box *b, wchar_t w, float prob ) {
	gocr_Char		*c, *tmp;

	if (b == NULL) {
		_gocr_printf(1, FUNCTION, "Box is NULL.\n");
		return -1;
	}
	if (prob < 0 || prob > 1.0) {
		_gocr_printf(1, FUNCTION, "Probability out of bounds.\n");
		return -1;
	}

	/* check if it's already in the list */
	for_each_data(&b->possible) {
		tmp = (struct gocr_char *)list_get_current(&b->possible);
		if (tmp->c == w) {
			if ( prob == 0.0 ) { /* take it out of the list */
				list_del(&b->possible, tmp);
			}
			else {
				/* what to do with probabilities? fuzzy? */
				tmp->prob = (tmp->prob > prob ? tmp->prob : prob);
			}

			list_lower_level(&b->possible);
			return 0;
		}
	} end_for_each(&b->possible);

	/* no, it is not */
	c = (gocr_Char *)malloc(sizeof(gocr_Char));
	if (c == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc.\n");
		return -1;
	}

	c->c = w;
	c->prob = prob;
	
/*	hash tables or lists? sorted by what?  for now, quick hack */
	b->ch = c;

	return list_app(&b->possible, c);
}

#if 0
/**
  \brief Returns the character with higher probability

  Long description. 
 
  \param b The box.
  \return The character with higher probability.
*/
wchar_t gocr_boxCharHigher ( gocr_Box *b ) {
	return b->ch->c;
}
#endif
