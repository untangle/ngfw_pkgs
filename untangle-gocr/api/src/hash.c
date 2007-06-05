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

#include "hash.h"
#include <stdlib.h>
#include <string.h>

#ifndef CHAIN
static const hashItem deletednode = { NULL, NULL };
#endif

/* internal Hash generator */
static int hash ( char *key ) {
  unsigned int hash = 0;

  while ( *key ) {
    /* this algorithm is from Bob Stout's Snippets collection, and was written
      by Jerry Coffin and HenkJan Wolthuis and released under public domain */
    hash ^= *key++;
    hash <<= 1;
  }

  return hash;
}

/* Given a key, returns the data associated with it. */
void *hash_data ( HashTable *t, char *key ) {
  unsigned int index, initial;
#ifdef CHAIN
  hashItem *h;
#endif
  
  if ( t == NULL || t->size <= 0 || t->hash_func == NULL || key == NULL )
    return NULL;

  /* must be two lines (compiler bug?) */
  index = t->hash_func(key);
  index %= t->size;

#ifdef CHAIN
  for ( h = t->item[index]; h != NULL; h = h->next )
    if ( strcmp(key, h->key) == 0 )
      return h->data;
#else
  while ( t->item[index] ) {
    if ( t->item[index]->key == NULL || strcmp(key, t->item[index]->key) != 0 ) {
      index = (index+1)%t->size;
      if ( index == initial ) { /* not found */
	return NULL;
      }
    }
    else { /* found */
      return t->item[index]->data;
    }
  }
#endif

  return NULL;
}

/* Deletes the entry associated with key. Returns a pointer to the data 
structure, which is not freed. */
void *hash_del ( HashTable *t, char *key ) {
  unsigned int initial, index;
  void *data;
#ifdef CHAIN
  hashItem *h, *last = NULL;
#endif
  
  if ( t == NULL || t->size <= 0 || t->hash_func == NULL || key == NULL )
    return NULL;

  initial = index = t->hash_func(key);
  initial %= t->size;

#ifdef CHAIN
  for ( h = t->item[index]; h != NULL; h = h->next ) {
    if ( strcmp(key, h->key) == 0 ) {
      /* fix list */
      if ( last )
	last->next = h->next;
      else /* is first item */
	t->item[index] = h->next;
      free(h->key);
      data = h->data;
      free(h);
      h = NULL;
      return data;
    }
    last = h;
  }
#else
  while ( t->item[index] ) {
    if ( strcmp(key, t->item[index]->key) != 0 ) {
      index = (index+1)%t->size;
      if ( index == initial ) { /* not found */
	return NULL;
      }
    }
    else { /* found */
      free(t->item[index]->key);
      data = t->item[index]->data;
      free(t->item[index]);
      (const hashItem *)t->item[index] = &deletednode;
      return data;
    }
  }
#endif

  return NULL;
}

/* Frees the hash table contents (but not the table). If free_func is not NULL,
it's called for every data stored in the table */
int hash_free ( HashTable *t, void (*free_func)(void *) ) {
  int i;
#ifdef CHAIN
  hashItem *h, *next = NULL;
#endif

  if ( t == NULL || t->size <= 0 || t->hash_func == NULL )
    return -1;

  for ( i = 0; i < t->size; i++ ) {
#ifdef CHAIN
    for ( h = t->item[i]; h != NULL; h = next ) {
      next = h->next;
      if ( h->key )
	free(h->key);
      if ( free_func )
      	free_func(h->data);
      free(h);
    }
#else
    if ( t->item[i] != NULL && t->item[i] != &deletednode ) {
      if ( t->item[i]->key )
	free(t->item[i]->key);
      if ( free_func )
      	free_func(t->item[i]->data);
      free(t->item[i]);
    }
#endif
  }
  free(t->item);

  t->size = 0;
  return 0;
}

/* Initialize a hash table, with size entries, using hash_func as the hash
generator func. If t is NULL, the function automaticall mallocs memory for it.
If hash_func is NULL, the default internal is used. Returns -1 on error, 0 if
OK. */
int hash_init ( HashTable *t, int size, int (* hash_func)(char *) ) {
  if ( size <= 0 )
    return -1;

  if ( t == NULL ) {
    t = (HashTable *)malloc(sizeof(HashTable));
    if ( t == NULL )
      return -1;
  }

  t->size = size;
  t->item = (hashItem **)malloc(sizeof(hashItem *)*size);
  if ( t->item == NULL ) {
    t->size = 0;
    return -1;
  }
  for ( size-- ; size >= 0; size-- )
    t->item[size] = NULL;

  if ( hash_func )
    t->hash_func = hash_func;
  else
    t->hash_func = hash;

  return 0;
}

/* Inserts a new entry in table t, with key key, which will contain data.
Returns -2 if data already exists, -1 on error, else the hash. */
int hash_insert ( HashTable *t, char *key, void *data ) {
  unsigned int index, initial;
#ifdef CHAIN
  hashItem *h;
#endif

  if ( t == NULL || t->size <= 0 || t->hash_func == NULL || key == NULL )
    return -1;

  index = t->hash_func(key);
  index %= t->size;
  initial = index;

  /* if index is free, fill it */
  if ( t->item[index] == NULL ) { 
    t->item[index] = (hashItem *)malloc(sizeof(hashItem));
    if ( t->item[index] == NULL )
      return -1;

    t->item[index]->key  = strdup(key);
    if ( !t->item[index]->key )
	    return -1;
    t->item[index]->data = data;
#ifdef CHAIN
    t->item[index]->next = NULL;
#endif

    return index;
  }

#ifdef CHAIN
  /* no, then find if the key already exists, and reach the last link */
  for ( h = t->item[index]; h->next != NULL; h = h->next )
    if ( strcmp(key, h->key) == 0 )
      return -2;

  h->next = (hashItem *)malloc(sizeof(hashItem));
  if ( h->next == NULL )
    return -1;

  h->next->key  = strdup(key);
  h->next->data = data;
  h->next->next = NULL;
#else
  /* no, then find next one free. Using linear probing. */
  while ( t->item[index] != NULL ) {
    index = (index+1) % t->size;
    if ( index == initial ) /* full */
      return -1;
    if ( strcmp(key, t->item[index]->key) == 0 )
      return -2;
  }

  t->item[index] = (hashItem *)malloc(sizeof(hashItem));
  if ( t->item[index] == NULL )
    return -1;

  t->item[index]->key  = strdup(key);
  t->item[index]->data = data;
#endif

  return index;
}

/* Given data, searches the table t for its first occurrence, and returns the 
key related to it. */
char *hash_key ( HashTable *t, void *data ) {
  int i;
#ifdef CHAIN
  hashItem *h;
#endif

  for ( i = 0; i < t->size; i++ ) {
#ifdef CHAIN
    h = t->item[i];
    while ( h ) {
      if ( h->data == data )
	return h->key;
      h = h->next;
    }
#else
    if ( t->item[i] && t->item[i]->data == data )
      return t->item[i]->key;
#endif
  }
  return NULL;
}
