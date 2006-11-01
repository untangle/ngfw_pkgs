/*
GOCR Copyright (C) 2000  Joerg Schulenburg
GOCR API Copyright (C) 2001 Bruno Barberi Gnecco

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

#ifndef _GOCR_HASH_H
#define _GOCR_HASH_H

struct hashitem {
	char		*key;
	void		*data;
#ifdef CHAIN
	struct hashitem *next;
#endif
};
typedef struct hashitem hashItem;

struct hashtable {
	int		size;
	hashItem	**item;
	int		(* hash_func)(char *);
};
typedef struct hashtable HashTable;

extern void *hash_data ( HashTable *t, char *key );
extern void *hash_del ( HashTable *t, char *key );
extern int hash_free ( HashTable *t, void (*free_func)(void *) );
extern int hash_init ( HashTable *t, int size, int (*hash_func)(char *) );
extern int hash_insert ( HashTable *t, char *key, void *data );
extern char *hash_key ( HashTable *t, void *data );

#endif
