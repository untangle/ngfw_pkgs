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
#include <string.h>
#include <stdarg.h>

static HashTable blockAttrib, charAttrib;

struct charattribute {
	/* name is the hash key, so don't waste memory holding it twice */
	unsigned char		*format;	/* like printf */
	gocr_CharAttributeType	type;
	int			index;		/* hash/attribute index */
	union {
	  int			settable;
	  unsigned char		*value;
	} data;
};

int _gocr_initUnicode ( void ) {
	struct initial {
		char *name;
		gocr_CharAttributeType type;
		char *format;
	};

	const struct initial chardata[] = { 
		{ "BOLD", SETTABLE, NULL },
		{ "ITALIC", SETTABLE, NULL },
		{ "SUBSCRIPT", SETTABLE, NULL },
		{ "SUPERCRIPT", SETTABLE, NULL },
		{ "FONT", UNTIL_OVERRIDEN, "%s %d" }
	};
	int i;

	if (hash_init(&blockAttrib, 0xFF, NULL) == -1) {
		_gocr_printf(1, "_gocr_initUnicode", "hash_init(block)\n");
			return -1;
	}
	if (hash_init(&charAttrib, 0xFF, NULL) == -1) {
		_gocr_printf(1, "_gocr_initUnicode", "hash_init(char)\n");
			return -1;
	}

	for (i = 0; i < sizeof(chardata) / sizeof(struct initial); i++) 
		if (gocr_charAttributeRegister(chardata[i].name, 
				chardata[i].type, chardata[i].format))
			return -1;

	return 0;
}

/* Frees a ca structure, used by endUnicode */
static void _free_ca ( void *data ) {
	struct charattribute *ca = (struct charattribute *)data;
	if (ca == NULL)
		return;
	if (ca->format)
		free(ca->format);
	free(ca);
}


void _gocr_endUnicode ( void ) {
	hash_free(&blockAttrib, NULL);
	hash_free(&charAttrib, _free_ca);
}

#define FUNCTION		"gocr_charAttributeRegister"
/**
  \brief Register a character attribute

  This functions registers a certain attribute...
  Long description.

  \param name The attribute name.
  \param t The attribute type, which is either SETTABLE or UNTIL_OVERRIDEN.
  \param format A printf-like string with the attribute format.
  \retval 0 OK
  \retval -1 error.
*/
int gocr_charAttributeRegister ( char *name, gocr_CharAttributeType t,
			       char *format ) {
	struct charattribute 		*ca;

	_gocr_printf(3, FUNCTION, "(%s, %d, \"%s\")\n", name, t, format);

	if (!name) {
		_gocr_printf(1, FUNCTION, "NULL name\n");
		return -1;
	}

	/* fill structure */
	ca = (struct charattribute *)malloc(sizeof(struct charattribute));
	if (ca == NULL) {
		_gocr_printf(1, FUNCTION, "NULL malloc\n");
		return -1;
	}

	switch (t) {
	  case SETTABLE:
		ca->data.settable = 0;
		break;
	  case UNTIL_OVERRIDEN:
		ca->data.value = NULL;
		break;
	  default:
		_gocr_printf(1, FUNCTION, "type %d does not exist\n", t);
			free(ca);
		return -1;
	}
	ca->type = t;

	/* future: check format to see if it's a valid one */
	ca->format =
		(format == NULL ? NULL : (unsigned char *)strdup(format));

	ca->index = hash_insert(&charAttrib, name, (void *)ca);
	if (ca->index < 0) {
		_gocr_printf(1, FUNCTION, "Hash error %d\n", ca->index);
		if (ca->format)
			free(ca->format);
		free(ca);
	}

	return 0;
}

int gocr_boxAttributeSet ( gocr_Box *box, int action, char *name, ... ) {
  wchar_t *t;
  int length;
  struct charattribute *ca;

  _gocr_debug(3, fprintf(_data.error, "gocr_charAttributeInsert(%p, %d, %s,...)", 
      box, action, name);)
  if ( name == NULL ) {
    _gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: NULL name\n");)
    return -1;
  }

  ca = (struct charattribute *)hash_data(&charAttrib, name);
  if ( ca == NULL ) {
    _gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: attribute not found\n");)
    return -1;
  }

  if ( action == 1 ) { /* insert */
    unsigned char *buffer = NULL, *p;

    /* check if it already exists */
    for ( t = box->attributes; *t != '\0'; t++ ) {
      if ( *t == gocr_setcharAttribute(ca->index) ) {
	_gocr_debug(2, fprintf(_data.error, "gocr_charAttributeInsert: attribute exists\n");)
	return -1;
      }
    }

    /* create format string */
    if ( ca->format != NULL ) {
      int size = 100;
      va_list va;

      va_start(va, name);

      /* fill the buffer */
      buffer = (unsigned char *)malloc(size);
      if ( buffer == NULL ) {
  	_gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: NULL malloc\n");)
  	return -1;
      }

      /* sprintf, making sure it fits */
      while (1) {
  	int nchars = vsnprintf (buffer, size, ca->format, va);

  	if (nchars > -1)
  	  break;

  	size *= 2;
  	buffer = (unsigned char *)realloc(buffer, size);
  	if ( buffer == NULL ) {
  	  _gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: NULL realloc %d\n", size);)
  	  return -1;
  	}
      }
      va_end(va);

    }
    /* point t to the end of the the string, realloc to fit */
    length = (box->attributes == NULL ? 0 : wcslen(box->attributes));
    box->attributes = (wchar_t *)realloc(box->attributes, (length +
  		  (buffer == NULL ? 0 : strlen(buffer)) + 2)*sizeof(wchar_t));
    if ( box->attributes == NULL ) {
      _gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: NULL wrealloc\n");)
      return -1;
    }
    t = box->attributes + wcslen(box->attributes);

    /* and fill with the data */
    *t++ = gocr_setcharAttribute(ca->index);
    for ( p = buffer; *p != '\0'; p++ )
      *t++ = gocr_setcharAttributeData(*p);
    *t = '\0';

    switch ( ca->type ) {
      case SETTABLE: /* it's a settable attribute, so set/unset it */
  	ca->data.settable = !ca->data.settable;
  	break;
      case UNTIL_OVERRIDEN:
  	if ( ca->data.value )
  	  free(ca->data.value);
  	ca->data.value = (unsigned char*)strdup(buffer);
  	break;
      default:
  	_gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: unexistant type\n");)
    }

    if ( buffer )
      free(buffer);
  }
  else if ( action == 0 ) { /* delete */
    wchar_t c = gocr_setcharAttribute(ca->index), *s;

    if ( !box->attributes )
      return 0;

    /* find the attribute */
    for ( t = box->attributes; *t != '\0'; t++ )
      if ( *t == c )
	break;
    if ( *t == '\0' ) /* not found */
      return 0;

    /* find the end of the attribute */
    for ( s = t+1; gocr_ischarAttributeData(*s); s++ ) 
      ;

    /* move the rest of the string, and realloc it */
    memmove(t, s, (wcslen(s)+1)*sizeof(wchar_t));
    box->attributes = (wchar_t *)realloc(box->attributes,
	(wcslen(box->attributes)+1)*sizeof(wchar_t));
    
    switch ( ca->type ) {
      case SETTABLE: /* it's a settable attribute, so set/unset it */
  	ca->data.settable = !ca->data.settable;
  	break;
      case UNTIL_OVERRIDEN:
	/*TODO: must search the previous value, etc */
	_gocr_debug(0, fprintf(_data.error, "gocr_charAttributeInsert: UNTIL_OVERRIDEN not done yet;\n"
			    "Unpredictable behaviour may occur.\n");)
  	break;
      default:
  	_gocr_debug(1, fprintf(_data.error, "gocr_charAttributeInsert: unexistant type\n");)
    }
  }

  return 0;
}

/**
  \brief Is an alphabetic character?

  Checks if the character is a 'letter', returning 1 if so. A 'letter' satisfies
  the following in unicode:

  ((c >= LATIN_CAPITAL_LETTER_A_WITH_GRAVE && c <= LATIN_CAPITAL_LETTER_O_WITH_DIAERESIS) ||
   (c >= LATIN_CAPITAL_LETTER_O_WITH_STROKE && c <= LATIN_SMALL_LETTER_O_WITH_DIAERESIS) ||
   (c >= LATIN_SMALL_LETTER_O_WITH_STROKE && c <= LATIN_LETTER_BIDENTAL_PERCUSSIVE) ||
   (c >= GREEK_CAPITAL_LETTER_ALPHA_WITH_TONOS && c <= GREEK_SMALL_LETTER_SAMPI) ||
   (c >= LATIN_SMALL_LIGATURE_FF && c <= LATIN_SMALL_LIGATURE_ST) )
   
  Which includes, but is not limited to:
    - Any standard latin letter [a-zA-Z]
    - Any accented latin letter (ALL accents)
    - Any of: ae, eth, thorn, sharp s
    - Any greek letter, with or without accents.
    - Any latin ligature

  \note Future versions may extend the list to other letters of other alphabets.
  \param c The character.
  \retval 1 It is.
  \retval 0 It isn't.
*/
int gocr_wcharIsAlpha ( wchar_t c ) {
	if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
	    (c >= LATIN_CAPITAL_LETTER_A_WITH_GRAVE &&
	    		c <= LATIN_CAPITAL_LETTER_O_WITH_DIAERESIS) ||
	    (c >= LATIN_CAPITAL_LETTER_O_WITH_STROKE &&
			c <= LATIN_SMALL_LETTER_O_WITH_DIAERESIS) ||
	    (c >= LATIN_SMALL_LETTER_O_WITH_STROKE &&
			c <= LATIN_LETTER_BIDENTAL_PERCUSSIVE) ||
	    (c >= GREEK_CAPITAL_LETTER_ALPHA_WITH_TONOS &&
			c <= GREEK_SMALL_LETTER_SAMPI) ||
	    (c >= LATIN_SMALL_LIGATURE_FF && c <= LATIN_SMALL_LIGATURE_ST))
		return 1;
	return 0;
}

#undef FUNCTION
#define FUNCTION		"gocr_compose"
/**
  \brief Composes characters

  This function intends to be a small helper, to avoid having to write
  switches in functions. It's therefore mainly to accents, and specially for
  the most usual ones. It supports the basic greek  characters too, which is
  actually not very helpful.
     
  \param main The character.
  \param modifier The modifier
  \return  the unicode character corresponding to the composed character.
*/
wchar_t gocr_compose ( wchar_t main, wchar_t modifier ) {

/* supported by now: part of ISO8859-1, basic greek characters */
	_gocr_printf(3, FUNCTION, "(%lx, %lx)\n", main,
			    modifier); 
	switch (modifier) {
	  case UNICODE_NULL:
	  case SPACE:
		return (wchar_t) main;

	  case APOSTROPHE:	/* do NOT USE this. It's here for compatibility only. 
				   Use ACUTE_ACCENT instead. */
		_gocr_printf(2, FUNCTION, "got APOSTROPHE instead of ACUTE_ACCENT");
	  case ACUTE_ACCENT:	/* acute/cedilla */
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_ACUTE;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_ACUTE;
		  case 'e':
			return LATIN_SMALL_LETTER_E_WITH_ACUTE;
		  case 'E':
			return LATIN_CAPITAL_LETTER_E_WITH_ACUTE;
		  case 'i':
			return LATIN_SMALL_LETTER_I_WITH_ACUTE;
		  case 'I':
			return LATIN_CAPITAL_LETTER_I_WITH_ACUTE;
		  case 'o':
			return LATIN_SMALL_LETTER_O_WITH_ACUTE;
		  case 'O':
			return LATIN_CAPITAL_LETTER_O_WITH_ACUTE;
		  case 'u':
			return LATIN_SMALL_LETTER_U_WITH_ACUTE;
		  case 'U':
			return LATIN_CAPITAL_LETTER_U_WITH_ACUTE;
		  case 'y':
			return LATIN_SMALL_LETTER_Y_WITH_ACUTE;
		  case 'Y':
			return LATIN_CAPITAL_LETTER_Y_WITH_ACUTE;
		  default:
			return (wchar_t) 0;
		}
		break;

	  case CEDILLA:
		switch (main) {
		  case 'c':
			return LATIN_SMALL_LETTER_C_WITH_CEDILLA;
		  case 'C':
			return LATIN_CAPITAL_LETTER_C_WITH_CEDILLA;
		}
		break;

	  case TILDE:
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_TILDE;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_TILDE;
		  case 'n':
			return LATIN_SMALL_LETTER_N_WITH_TILDE;
		  case 'N':
			return LATIN_CAPITAL_LETTER_N_WITH_TILDE;
		  case 'o':
			return LATIN_SMALL_LETTER_O_WITH_TILDE;
		  case 'O':
			return LATIN_CAPITAL_LETTER_O_WITH_TILDE;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case GRAVE_ACCENT:
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_GRAVE;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_GRAVE;
		  case 'e':
			return LATIN_SMALL_LETTER_E_WITH_GRAVE;
		  case 'E':
			return LATIN_CAPITAL_LETTER_E_WITH_GRAVE;
		  case 'i':
			return LATIN_SMALL_LETTER_I_WITH_GRAVE;
		  case 'I':
			return LATIN_CAPITAL_LETTER_I_WITH_GRAVE;
		  case 'o':
			return LATIN_SMALL_LETTER_O_WITH_GRAVE;
		  case 'O':
			return LATIN_CAPITAL_LETTER_O_WITH_GRAVE;
		  case 'u':
			return LATIN_SMALL_LETTER_U_WITH_GRAVE;
		  case 'U':
			return LATIN_CAPITAL_LETTER_U_WITH_GRAVE;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case QUOTATION_MARK:	/* do NOT USE this. It's here for compatibility only. 
				   Use DIAERESIS instead. */
		_gocr_printf(2, FUNCTION, "QUOTATION_MARK instead of DIAERESIS");
	  case DIAERESIS:
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_DIAERESIS;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_DIAERESIS;
		  case 'e':
			return LATIN_SMALL_LETTER_E_WITH_DIAERESIS;
		  case 'E':
			return LATIN_CAPITAL_LETTER_E_WITH_DIAERESIS;
		  case 'i':
			return LATIN_SMALL_LETTER_I_WITH_DIAERESIS;
		  case 'I':
			return LATIN_CAPITAL_LETTER_I_WITH_DIAERESIS;
		  case 'o':
			return LATIN_SMALL_LETTER_O_WITH_DIAERESIS;
		  case 'O':
			return LATIN_CAPITAL_LETTER_O_WITH_DIAERESIS;
		  case 'u':
			return LATIN_SMALL_LETTER_U_WITH_DIAERESIS;
		  case 'U':
			return LATIN_CAPITAL_LETTER_U_WITH_DIAERESIS;
		  case 'y':
			return LATIN_SMALL_LETTER_Y_WITH_DIAERESIS;
		  case 'Y':
			return LATIN_CAPITAL_LETTER_Y_WITH_DIAERESIS;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case CIRCUMFLEX_ACCENT:
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_CIRCUMFLEX;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_CIRCUMFLEX;
		  case 'e':
			return LATIN_SMALL_LETTER_E_WITH_CIRCUMFLEX;
		  case 'E':
			return LATIN_CAPITAL_LETTER_E_WITH_CIRCUMFLEX;
		  case 'i':
			return LATIN_SMALL_LETTER_I_WITH_CIRCUMFLEX;
		  case 'I':
			return LATIN_CAPITAL_LETTER_I_WITH_CIRCUMFLEX;
		  case 'o':
			return LATIN_SMALL_LETTER_O_WITH_CIRCUMFLEX;
		  case 'O':
			return LATIN_CAPITAL_LETTER_O_WITH_CIRCUMFLEX;
		  case 'u':
			return LATIN_SMALL_LETTER_U_WITH_CIRCUMFLEX;
		  case 'U':
			return LATIN_CAPITAL_LETTER_U_WITH_CIRCUMFLEX;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case RING_ABOVE:
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_A_WITH_RING_ABOVE;
		  case 'A':
			return LATIN_CAPITAL_LETTER_A_WITH_RING_ABOVE;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case 'e':		/* e ligatures: ae, oe. */
	  case 'E':
		switch (main) {
		  case 'a':
			return LATIN_SMALL_LETTER_AE;
		  case 'A':
			return LATIN_CAPITAL_LETTER_AE;
		  case 'o':
			return LATIN_SMALL_LIGATURE_OE;
		  case 'O':
			return LATIN_CAPITAL_LIGATURE_OE;
		  default:
			return (wchar_t) 0;
		}
		break;
	  case 'g':		/* greek */
		switch (main) {
			/* missing 0x37A-0x390 */
			/* weird cases: Q -> theta (it resembles a little, doesn't it?)
			   V -> psi   (what can I do?) */
		  case 'A':
			return GREEK_CAPITAL_LETTER_ALPHA;
		  case 'B':
			return GREEK_CAPITAL_LETTER_BETA;
		  case 'G':
			return GREEK_CAPITAL_LETTER_GAMMA;
		  case 'D':
			return GREEK_CAPITAL_LETTER_DELTA;
		  case 'E':
			return GREEK_CAPITAL_LETTER_EPSILON;
		  case 'Z':
			return GREEK_CAPITAL_LETTER_ZETA;
		  case 'H':
			return GREEK_CAPITAL_LETTER_ETA;
		  case 'Q':
			return GREEK_CAPITAL_LETTER_THETA;
		  case 'I':
			return GREEK_CAPITAL_LETTER_IOTA;
		  case 'K':
			return GREEK_CAPITAL_LETTER_KAPPA;
		  case 'L':
			return GREEK_CAPITAL_LETTER_LAMDA;
		  case 'M':
			return GREEK_CAPITAL_LETTER_MU;
		  case 'N':
			return GREEK_CAPITAL_LETTER_NU;
		  case 'X':
			return GREEK_CAPITAL_LETTER_XI;
		  case 'O':
			return GREEK_CAPITAL_LETTER_OMICRON;
		  case 'P':
			return GREEK_CAPITAL_LETTER_PI;
		  case 'R':
			return GREEK_CAPITAL_LETTER_RHO;
		  case 'S':
			return GREEK_CAPITAL_LETTER_SIGMA;
		  case 'T':
			return GREEK_CAPITAL_LETTER_TAU;
		  case 'Y':
			return GREEK_CAPITAL_LETTER_UPSILON;
		  case 'F':
			return GREEK_CAPITAL_LETTER_PHI;
		  case 'C':
			return GREEK_CAPITAL_LETTER_CHI;
		  case 'V':
			return GREEK_CAPITAL_LETTER_PSI;
		  case 'W':
			return GREEK_CAPITAL_LETTER_OMEGA;
/*
	case '':   return GREEK_CAPITAL_LETTER_IOTA_WITH_DIALYTIKA;
	case '':   return GREEK_CAPITAL_LETTER_UPSILON_WITH_DIALYTIKA;
	case '':   return GREEK_SMALL_LETTER_ALPHA_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_EPSILON_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_ETA_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_IOTA_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_UPSILON_WITH_DIALYTIKA_AND_TONOS;
*/
		  case 'a':
			return GREEK_SMALL_LETTER_ALPHA;
		  case 'b':
			return GREEK_SMALL_LETTER_BETA;
		  case 'g':
			return GREEK_SMALL_LETTER_GAMMA;
		  case 'd':
			return GREEK_SMALL_LETTER_DELTA;
		  case 'e':
			return GREEK_SMALL_LETTER_EPSILON;
		  case 'z':
			return GREEK_SMALL_LETTER_ZETA;
		  case 'h':
			return GREEK_SMALL_LETTER_ETA;
		  case 'q':
			return GREEK_SMALL_LETTER_THETA;
		  case 'i':
			return GREEK_SMALL_LETTER_IOTA;
		  case 'k':
			return GREEK_SMALL_LETTER_KAPPA;
		  case 'l':
			return GREEK_SMALL_LETTER_LAMDA;
		  case 'm':
			return GREEK_SMALL_LETTER_MU;
		  case 'n':
			return GREEK_SMALL_LETTER_NU;
		  case 'x':
			return GREEK_SMALL_LETTER_XI;
		  case 'o':
			return GREEK_SMALL_LETTER_OMICRON;
		  case 'p':
			return GREEK_SMALL_LETTER_PI;
		  case 'r':
			return GREEK_SMALL_LETTER_RHO;
		  case '&':
			return GREEK_SMALL_LETTER_FINAL_SIGMA;
		  case 's':
			return GREEK_SMALL_LETTER_SIGMA;
		  case 't':
			return GREEK_SMALL_LETTER_TAU;
		  case 'y':
			return GREEK_SMALL_LETTER_UPSILON;
		  case 'f':
			return GREEK_SMALL_LETTER_PHI;
		  case 'c':
			return GREEK_SMALL_LETTER_CHI;
		  case 'v':
			return GREEK_SMALL_LETTER_PSI;
		  case 'w':
			return GREEK_SMALL_LETTER_OMEGA;
/*
	case '':   return GREEK_SMALL_LETTER_IOTA_WITH_DIALYTIKA;
	case '':   return GREEK_SMALL_LETTER_UPSILON_WITH_DIALYTIKA;
	case '':   return GREEK_SMALL_LETTER_OMICRON_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_UPSILON_WITH_TONOS;
	case '':   return GREEK_SMALL_LETTER_OMEGA_WITH_TONOS;
	case '':   return GREEK_BETA_SYMBOL;
	case '':   return GREEK_THETA_SYMBOL;
	case '':   return GREEK_UPSILON_WITH_HOOK_SYMBOL;
	case '':   return GREEK_UPSILON_WITH_ACUTE_AND_HOOK_SYMBOL;
	case '':   return GREEK_UPSILON_WITH_DIAERESIS_AND_HOOK_SYMBOL;
	case '':   return GREEK_PHI_SYMBOL;
	case '':   return GREEK_PI_SYMBOL;
*/
		  default:
			return (wchar_t) 0;
		}
		break;
	  default:
		return (wchar_t) 0;
	}
	return (wchar_t) 0;
}

