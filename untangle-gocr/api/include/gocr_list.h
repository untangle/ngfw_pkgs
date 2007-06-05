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

#ifndef _GOCR_LIST_H
#define _GOCR_LIST_H

/*! \file list.h
  \brief This is the linked list header
  \author Bruno Barberi Gnecco <brunobg@sourceforge.net>
*/

/** @name gocr_List
  */
/*@{*/
/**
  \brief Node structure.
*/
struct gocr_node {
	struct gocr_node	*next;		/**< Pointer to next node. */
	struct gocr_node	*previous;	/**< Pointer to prev node. */
	void			*data;		/**< Pointer to data. */
};
typedef struct gocr_node gocr_Node;

/**
  \brief gocr_List structure.
*/
struct gocr_list {
	gocr_Node 		*header;	/**< gocr_List header */
	gocr_Node 		*tail;		/**< gocr_List tail */
	gocr_Node 		**fix;		/**< fixes the list_del header problem */
	gocr_Node 		**current;	/**< for(each_element) data */
	int 			n;		/**< number of elements */
	int 			level;		/**< level of nested fors */
};
typedef struct gocr_list gocr_List;

/*
 * Functions
 */
void	list_init		( gocr_List *l );
int	list_app		( gocr_List *l, void *data );
int	list_ins		( gocr_List *l, void *data_after, void *data);
int	list_ins_order		( gocr_List *l, void *data,
					int (*say_when) (const void *, const void *) );
gocr_Node* list_node_from_data	( gocr_List *l, void *data );
int	list_del		( gocr_List *l, void *data );
void	list_free		( gocr_List *l );
int	list_higher_level	( gocr_List *l );
void	list_lower_level	( gocr_List *l );
void *	list_next		( gocr_List *l, void *data );
void *	list_prev		( gocr_List *l, void *data );
void	list_sort		( gocr_List *l, int (*compare)(const void *, const void *) );

/**
  \brief Is the list empty?
  \retval 0 No.
  \retval 1 Yes.
*/
#define list_empty(l)			((l)->header == NULL ? 1 : 0)

/**
  \brief Get header data
  \return The header data.
*/
#define list_get_header(l)		((l)->header->data)

/**
  \brief Get tail data
  \return The tail data.
*/
#define list_get_tail(l)		((l)->tail->data)

/**
  \brief Get current data
  \sa for_each_data.
  \return The current data.
*/
#define list_get_current(l)		((l)->current[(l)->level]->data)


#define list_get_cur_prev(l)		((l)->current[(l)->level]->previous == NULL ? \
			NULL : (l)->current[(l)->level]->previous->data )
#define list_get_cur_next(l)		((l)->current[(l)->level]->next == NULL ? \
			NULL : (l)->current[(l)->level]->next->data )

/**
  \brief Get number of nodes
  \return The number of nodes of the list.
*/
#define list_total(l)			((l)->n)

#define for_each_data(l)		\
 if (list_higher_level(l) == 0) { \
   for ( ; (l)->current[(l)->level]; (l)->current[(l)->level] = \
	(l)->current[(l)->level]->next ) { \
     if ( (l)->fix[(l)->level] ) { /* fix level */\
       int i; \
       for ( i = (l)->level - 1; i >= 0; i-- ) {  \
       /* check if some other copy of (l)->fix[(l)->level] exists */ \
        \
         if ( (l)->fix[i] == (l)->fix[(l)->level] ) break; \
       } \
       if ( i < 0 ) { /* no, it doesn't. Free it */ \
         free((l)->fix[(l)->level]); \
       } \
       (l)->fix[(l)->level] = NULL; \
     }

#define end_for_each(l)			\
   } \
 list_lower_level(l); \
 }

/*@}*/
#endif
