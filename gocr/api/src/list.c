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

/***********************************IMPORTANT*********************************
 Notes to the developers: read the following notes before using these
 functions.
   * Be careful when using for_each_data() recursively and calling list_del.
    It may mangle with the current[] pointers, and possibly segfault or do an
    unpredictable or just undesirable behavior. We have been working on a 
    solution for this problem, and solved some of the biggest problems.
     In a few words, the problem is this: when you delete a node, it may be
    the current node of a lower level loop. The current code takes care of
    access to previous/next nodes of the now defunct node. So, if you do
    something like:
  
    for_each_data(l) {
      for_each_data(l) {
	list_del(l, header_data);
	free(header_data);
      } end_for_each(l);
+     tempnode = list_cur_next(l);
    } end_for_each(l);

    It will work, even though the current node in the outer loop was deleted.
    However, if you replace the line marked with + with the following code:

      tempnode = list_next(l, list_get_current(l));

    it will break, since list_get_current is likely to return NULL or garbage,
    since you deleted header_data().
     Conclusion: use list_del carefully. The best way to avoid this problem is
    to not use list_del inside a big stack of loops.
   * Note that if you have two nodes with the same data, the list_* functions 
    will assume that the first one is the one you want. Not a bug, a feature. ;)
   * Avoid using list_prev/next. They are slow. 
 */

#include <stdio.h>
#include <stdlib.h>
#include "gocr_list.h"

/**
  \brief Initializes a new list.

  You must call this function before using any other list* function. The list
  must be allocated.

  Note that if you have two nodes with the same data, the functions will assume 
  that the first one is the wanted one. This is valid for every list_* function.
  Not a bug, a feature. Really. ;-)

  \param l A non-NULL pointer to the list.
  \sa list_free
*/
void list_init ( gocr_List *l ) {
	if (!l)
		return;

	l->header = l->tail = NULL;
	l->current = NULL;
	l->fix = NULL;
	l->level = -1;
	l->n = 0;
}

/**
  \brief Appends a node to the list.

  Appends a node to the end of the list.

  Note that if you have two nodes with the same data, the list_* functions 
  will assume that the first one is the one you want. Not a bug, a feature. 

  \param l A non-NULL pointer to the list.
  \param data The data to store in the list. Must be non-NULL.
  \sa list_ins, list_ins_order
  \retval 0 OK
  \retval -1 error.
*/
int list_app ( gocr_List *l, void *data ) {
	gocr_Node *e;

	if (!l || !data)
		return -1;

	e = (gocr_Node *)malloc(sizeof(gocr_Node));
	if (!e)
		return -1;

	e->data = data;
	if (!l->header) {
		l->header = l->tail = e;
		l->n = 1;
		e->previous = e->next = NULL;
		return 0;
	}

	l->tail->next = e;
	e->previous = l->tail;
	l->tail = e;
	e->next = NULL;
	l->n++;
	return 0;
}

/**
  \brief Inserts a node in the list.

  Inserts a node in the list, just before some other one. 
  
  Note that if you have two nodes with the same data, the list_* functions 
  will assume that the first one is the one you want. Not a bug, a feature. 

  \param l A non-NULL pointer to the list.
  \param data_after The data (already in the list) that should be after \e data.
    If data_after is NULL, appends to the end of the list.
  \param data The data to store in the list. Must be non-NULL.
  \sa list_app, list_ins_order
  \retval 0 OK
  \retval -1 error.
*/
int list_ins ( gocr_List *l, void *data_after, void *data ) {
	gocr_Node *e, *after_node;

	/* test arguments */
	if (!l || !data)
		return -1;

	if (!data_after || !l->header)
		return list_app(l, data);

	/* alloc a new node */
	if (!(e = (gocr_Node *) malloc(sizeof(gocr_Node))))
		return -1;
	e->data = data;

	/* get data_after node */
	if (!(after_node = list_node_from_data(l, data_after)))
		return -1;

	e->next = after_node;
	e->previous = after_node->previous;
	if (after_node->previous)	/* i.e., if after_node != list->header */
		after_node->previous->next = e;
	else			/* update list->header */
		l->header = e;
	after_node->previous = e;
	l->n++;

	return 0;
}

/**
  \brief Inserts a node in the list.

  Inserts a node in the list, in a position determined by a user function. 
  This function is very useful to keep sorted lists.

  The list is sweeped in order, and the \e say_when function is called for each
  node, receiving as first argument the data being inserted (from now on,
  data1) and as second the data being sweeped (from now on, data2). If \e
  say_when returns a value less than zero, data1 is inserted in the position 
  immediately before data2. If more than zero, data1 is inserted in the
  position immediately after data2. If zero, nothing is done.

  If all nodes are sweeped and the function returned zero to all of them, the
  new data is appended to the end of the list.

  Note that if you have two nodes with the same data, the list_* functions 
  will assume that the first one is the one you want. Not a bug, a feature. 

  \param l A non-NULL pointer to the list.
  \param data The data to store in the list. Must be non-NULL.
  \param say_when A pointer to a function that will determine the inserction
    point. The first argument is the data being inserted, the second is the 
    data sweeped from the list. See above.
  \sa list_app, list_ins, list_sort.
  \retval 0 OK
  \retval -1 error.
*/
int list_ins_order ( gocr_List *l, void *data,
		   int (*say_when) (const void *, const void *) ) {
	gocr_Node *new, *old;
	int r = 0;

	/* test arguments */
	if (!l || !data)
		return -1;

	if (!l->header || !say_when)
		return list_app(l, data);

	old = l->header;
	/* get data node */
	while (old != NULL) {
		if ((r = say_when(data, old->data)) != 0) {
			break;
		}
		old = old->next;
		if (!old)
			return list_app(l, data);
	}

	/* alloc a new node */
	if (!(new = (gocr_Node *) malloc(sizeof(gocr_Node))))
		return -1;
	new->data = data;

	if (r > 0) { /* insert after old */
		new->next = old->next;
		new->previous = old;
		if (old->next)	/* i.e., if old != list->tail */
			old->next->previous = new;
		else			/* update list->header */
			l->tail = new;
		old->next = new;
	}
	else { /* insert before old */
		new->next = old;
		new->previous = old->previous;
		if (old->previous)	/* i.e., if after_node != list->header */
			old->previous->next = new;
		else			/* update list->header */
			l->header = new;
		old->previous = new;
	}
	l->n++;

	return 0;
}


/**
  \brief Returns the node associated with data

  Returns the node associated with data, or NULL is none is found. You should
  use the node if you need to do some low-level processing on the list, or
  are looking for speed.

  \param l A non-NULL pointer to the list.
  \param data The data. Must be non-NULL.
  \sa list_higher_level, list_lower_level
  \retval 0 OK
  \retval -1 error.
*/
gocr_Node *list_node_from_data ( gocr_List *l, void *data ) {
	gocr_Node *temp;

	if (!l || !data)
		return NULL;

	if (!(temp = l->header))
		return NULL;

	while (temp->data != data) {
		temp = temp->next;
		if (!temp)
			return NULL;
	}
	return temp;
}

/**
  \brief Deletes a node of the list

  Deletes the node associated with data from the list. Take care with this
  function, since it may damage for_each_data loops.
  
  Be careful when using for_each_data() recursively and calling list_del. It
  may mangle the current[] pointers, and possibly segfault or do unpredictable
  or just undesirable behavior. We have been working on a solution for this
  problem, and solved some of the biggest problems. In a few words, the problem
  is this: when you delete a node, it may be the current node of a lower level
  loop. The current code takes care of access to previous/next nodes of the now
  defunct node. So, if you do something like:

    for_each_data(l) {
      for_each_data(l) {
	list_del(l, header_data);
	free(header_data);
      } end_for_each(l);
  +   tempnode = list_cur_next(l);
    } end_for_each(l);

   It will work, even though the current node in the outer loop was deleted.
   However, if you replace the line marked with + with the following code:

      tempnode = list_next(l, list_get_current(l));

   it will break, since list_get_current is likely to return NULL or garbage,
   since you deleted header_data().

   Conclusion: use list_del carefully. The best way to avoid this problem is
   to not use list_del inside a big stack of loops.

  \param l A non-NULL pointer to the list.
  \param data The data. Must be non-NULL.
  \sa list_free
  \retval 0 OK
  \retval -1 error.
*/
int list_del ( gocr_List *l, void *data ) {
	gocr_Node *temp;
	int i;

	/* find node associated with data */
	if (!(temp = list_node_from_data(l, data)))
		return -1;

	/* test if the deleted node is current in some nested loop, and fix it. */
	for (i = l->level; i >= 0; i--) {
		if (l->current[i] == temp) {
			l->fix[i] = temp;
		}
	}

	/* fix previous */
	if (temp == l->header) {
		l->header = temp->next;
		if (l->header)
			l->header->previous = NULL;
	}
	else
		temp->previous->next = temp->next;

	/* fix next */
	if (temp == l->tail) {
		l->tail = temp->previous;
		if (l->tail)
			l->tail->next = NULL;
	}
	else
		temp->next->previous = temp->previous;

	/* and free stuff */
	free(temp);
	l->n--;
	return 0;
}

/**
  \brief Frees a list

  Frees the list contents. Does NOT free the data in it.

  \param l A non-NULL pointer to the list.
  \param data The data. Must be non-NULL.
  \sa list_del
*/
/* Should we receive a pointer to a function that frees data? */
void list_free ( gocr_List *l ) {
	gocr_Node *temp, *temp2;

	if (!l)
		return;
	if (!l->header)
		return;

	if (l->current) {
		free(l->current);
	}
	l->current = NULL;

	if (l->fix) {
		free(l->fix);
	}
	l->fix = NULL;

	temp = l->header;
	while (temp) {
		temp2 = temp->next;
		free(temp);
		temp = temp2;
	}
	l->header = l->tail = NULL;
}

/**
  \brief Risens list level

  Setups a new level of for_each data. Used mostly internally.

  \param l A non-NULL pointer to the list.
  \sa list_lower_level
  \retval 0 OK
  \retval -1 error.
*/
int list_higher_level ( gocr_List *l ) {
	gocr_Node **newcur;
	gocr_Node **newfix;

	if (!l || !l->header)
		return -1;

	newcur = (gocr_Node **) realloc(l->current,
				      (l->level + 1) * sizeof(gocr_Node *));
	newfix = (gocr_Node **) realloc(l->fix,
				      (l->level + 1) * sizeof(gocr_Node *));
	if (!newcur || !newfix) {	/* doesn't blow everything */
/*    _gocr_debug(1, fprintf(_data.error, " realloc failed! level++=%d current[]=%p fix[]=%p\n", 
	l->level, l->current, l->fix);) */
		return -1;
	}
	l->current = newcur;
	l->fix = newfix;
	l->level++;
	l->current[l->level] = l->header;
	l->fix[l->level] = NULL;
/*  _gocr_debug(3, fprintf(_data.error, " level++=%d current[]=%p fix[]=%p\n", 
      l->level, l->current, l->fix);) */
	return 0;
}

/**
  \brief Lowers list level

  Deletes the highest level of for_each data. Used mostly internally.

  \param l A non-NULL pointer to the list.
  \sa list_lower_level
*/
void list_lower_level ( gocr_List *l ) {
	if (!l)
		return;

	l->current = (gocr_Node **) realloc(l->current, l->level * sizeof(gocr_Node *));
	l->fix = (gocr_Node **) realloc(l->fix, l->level * sizeof(gocr_Node *));
	l->level--;
/*  _gocr_debug(3, fprintf(_data.error, " level--=%d current[]=%p fix[]=%p\n",
      l->level, l->current, l->fix);) */
}

/**
  \brief Returns data in the next node

  Returns the data associated with the next node in the list.
  
  Avoid calling this function. It is intensive and slow. Keep the result in
  a variable or, if you need something more, use list_get_node_from_data.

  \param l A non-NULL pointer to the list.
  \param data The data. Must be non-NULL.
  \sa list_prev, list_node_from_data
  \return The data associated with the next node.
*/
void *list_next ( gocr_List *l, void *data ) {
	gocr_Node *temp;

	if (!l || !(temp = list_node_from_data(l, data)))
		return NULL;
	if (!temp->next)
		return NULL;
	return (temp->next->data);
}

/**
  \brief Returns data in the previous node

  Returns the data associated with the previous node in the list.
  
  Avoid calling this function. It is intensive and slow. Keep the result in
  a variable or, if you need something more, use list_get_node_from_data.

  \param l A non-NULL pointer to the list.
  \param data The data. Must be non-NULL.
  \sa list_next, list_node_from_data
  \return The data associated with the previous node.
*/
void *list_prev ( gocr_List *l, void *data ) {
	gocr_Node *temp;

	if (!l || !(temp = list_node_from_data(l, data)))
		return NULL;
	if (!temp->previous)
		return NULL;
	return (temp->previous->data);
}

/**
  \brief Sorts a list

  Similar to qsort. Sorts list, using the (*compare) function, which is 
  provided by the user. The comparison function must return an integer less 
  than, equal to, or greater than zero if the first argument is considered to 
  be respectively less than, equal to, or greater than the second. 
  Uses the bubble sort algorithm.

  \param l A non-NULL pointer to the list.
  \param compare The compare function.
  \sa list_ins_order
*/
void list_sort ( gocr_List *l, int (*compare) (const void *, const void *) ) {
	gocr_Node *temp, *prev;
	int i;

	if (!l)
		return;

	for (i = 0; i < l->n; i++) {
		for (temp = l->header->next; temp != NULL; temp = temp->next) {
			if (compare((const void *)temp->previous->data,
			     (const void *)temp->data) > 0) {

				/* swap with the previous node */
				prev = temp->previous;

				if (prev->previous)
					prev->previous->next = temp;
				else	/* update header */
					l->header = temp;

				temp->previous = prev->previous;
				prev->previous = temp;
				prev->next = temp->next;
				if (temp->next)
					temp->next->previous = prev;
				else	/* update tail */
					l->tail = prev;
				temp->next = prev;

				/* and make sure the node in the for loop is correct */
				temp = prev;

#ifdef SLOWER_BUT_KEEP_BY_NOW
/* this is a slower version, but guaranteed to work */
				void *data;

				data = temp->data;
				prev = temp->previous;
				list_del(l, data);
				list_ins(l, prev->data, data);
				temp = prev;
#endif
			}
		}
	}
}

