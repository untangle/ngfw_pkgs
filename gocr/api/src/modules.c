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

#include <string.h>
#include <ltdl.h>
#include <stdarg.h>
#include "_gocr.h"
#include "gocr.h"

gocr_List liblist;
gocr_List modulefunclist[allModules];
gocr_Block empty;

static gocr_ModuleId 		currentlibid = 0;
static gocr_ModuleFunctionId	currentfuncid[allModules] = {
	0, 0, 10000, 20000, 30000, 40000, 50000 };

#define _gocr_getfunctype(func)		((func/10000)+1)
#define _gocr_getnewfuncid(type)	(currentfuncid[type]++)

struct _gocr_lib {
	void 			*handle;
	gocr_ModuleId 		id;
	char			*name;
	int 			(*setAttrib) (char *, char *);
	gocr_ModuleInfo		*info;
};

struct _gocr_modulefunction {
	gocr_ModuleFunctionId	id;
	struct _gocr_lib 	*l;
	char 			*name;
	void 			*data;

	union {
		void (*imageFilter) (gocr_Image *src, void *v);		
//		void (*imageFilter) (gocr_Image *src, gocr_Image *target, void *v);
		void (*blockFinder) (gocr_Image *img, void *v);
//		int (*blockFinder) (gocr_Image *img, gocr_Block **b, void *v);
		int (*charFinder) (gocr_Block *b, void *v);
//		int (*charFinder) (gocr_Block *bl, gocr_Box **b, void *v);
		int (*charRecognizer) (gocr_Box *b, void *v);
		void (*contextCorrection) (gocr_Box *b, void *v);
		void (*outputFormatter) (gocr_Block **bl, void *v);
	} func;
};

/*
 * Internal functions
 */

int _gocr_initModule ( void ) {
	gocr_ModuleType 		i;
	int 				r;

	/* init lists */
	list_init(&liblist);
	for (i = 0; i < allModules; i++) {
		list_init(&modulefunclist[i]);
	}

	/* init libltdl */
	r = lt_dlinit();
	if (r) {
		_gocr_printf(1, "_gocr_initModule", "%s", lt_dlerror());
		return r;
	}
#if 0
	lt_dladdsearchdir(GOCR_PATH);
#endif
	return 0;
}

void _gocr_endModule ( void ) {
	gocr_ModuleType 		i;
	struct _gocr_modulefunction 	*m;

	for (i = imageFilter; i < allModules; i++) {
		for_each_data(&modulefunclist[i]) {
			m = (struct _gocr_modulefunction *)
				list_get_current(&modulefunclist[i]);
			if (m) {
				if (m->name) {
					free(m->name);
					m->name = NULL;
				}
				free(m);
			}
		} end_for_each(&modulefunclist[i]);
		list_free(&modulefunclist[i]);
	}

	for_each_data(&liblist) {
		struct _gocr_lib *t =
				(struct _gocr_lib *)list_get_current(&liblist);
		lt_dlclose(t->handle);
		free(t);
	} end_for_each(&liblist);
	list_free(&liblist);

	lt_dlexit();
}


/*
 * External Functions
 */

#define FUNCTION		"gocr_moduleLoad"
/**
  \brief opens a module package

  Long description.

  \param filename The name of the module file.
  \sa gocr_moduleClose
  \return the module id (an integer >= 0), or -1 if error.
*/
gocr_ModuleId gocr_moduleLoad ( char *filename ) {
	gocr_ModuleFunctionInfo		*finfo;
	struct _gocr_lib 		*l;
	int 				(*init_func) (void);

	_gocr_printf(3, FUNCTION, "(%s)\n", filename);
	l = (struct _gocr_lib *)malloc(sizeof(struct _gocr_lib));
	if (!l) {
		_gocr_printf(1, FUNCTION, "Not enough memory\n");
		return -1;
	}

	l->handle = lt_dlopen(filename);
	if (!l->handle) {
		_gocr_printf(1, FUNCTION, "Could not open module %s: %s\n",
			     filename, lt_dlerror());
		return -1;
	}
	
	/* try to open an init function */
	init_func = lt_dlsym(l->handle, "initModule");
	if (init_func) {
		int r;

		_gocr_printf(3, FUNCTION, "Running init_func of %s\n", filename);
		r = init_func();
		if (r != 0) {
			_gocr_printf(1, FUNCTION, 
					"%s init function returned %d\n",
					filename, r);
			lt_dlclose(l->handle);
			free(l);
			return -1;
		}
	}

	/* get information from the module */
	l->info = lt_dlsym(l->handle, "gocr_extModuleData");
	if (!l->info) {
		_gocr_printf(1, FUNCTION, "Cannot open %s: couldn't get ModuleInfo.\n",
				filename);
		lt_dlclose(l->handle);
		free(l);
		return -1;
	}
	_gocr_printf(2, FUNCTION, "Loading module: %s version %s, by %s\n", 
			l->info->name, l->info->version, l->info->authors);
	finfo = l->info->functions;
	while (finfo->function) { /* just check them */
		if (finfo->type == allModules) {
			_gocr_printf(1, FUNCTION, "Invalid type:"
					"ignoring function %s\n",
					finfo->function);
/* todo */
		}
		else  {
			_gocr_printf(3, FUNCTION, "exported: %s [%s] %d\n", 
					finfo->function, 
					finfo->description, finfo->type);
		}
		finfo++;
	}

	if (l->info->attributes[0].name) {
		/* try to open the setAttrib function */
		l->setAttrib = lt_dlsym(l->handle, "setAttribute");
		if (!l->setAttrib) {
			_gocr_printf(1, FUNCTION, "Attribute list exists,"
					"but can't open function: %s\n"
					"You won't be able to set attributes",
					lt_dlerror());
		}
	}

	l->id = currentlibid++;
	l->name = strdup(filename);

	list_app(&liblist, l);
	return l->id;
}

#undef FUNCTION
#define FUNCTION		"gocr_moduleClose"
/**
  \brief closes a module

  Given the library id, closes the module and frees every module function
  associated with it. 

  \param id The module id.
  \sa gocr_moduleLoad
*/
void gocr_moduleClose ( gocr_ModuleId id ) {
	void 				(*close) (void);
	struct _gocr_lib 		*l;
	struct _gocr_modulefunction 	*m;
	gocr_ModuleType 		t;

	_gocr_printf(3, FUNCTION, "(%d)\n", id);
	/* search module */
	for_each_data(&liblist) {
		l = (struct _gocr_lib *)list_get_current(&liblist);
		if (l->id == id)
			break;
	}
	end_for_each(&liblist);

	if (l->id != id) {	/* module not found */
		_gocr_printf(1, FUNCTION, "Module %d not found\n", id);
		return;
	}

	close = lt_dlsym(l->handle, "closeModule");
	if (close)
		close();

	for (t = 0; t < allModules; t++) {
		for_each_data(&modulefunclist[t]) {
			m = (struct _gocr_modulefunction *)
				list_get_current(&modulefunclist[t]);
			if (m->l == l) {
				if (m->name)
					free(m->name);
				list_del(&modulefunclist[t], m);
				free(m);
			}
		}
		end_for_each(&modulefunclist[t]);
	}

	lt_dlclose(l->handle);
	list_del(&liblist, l);
	free(l);
}

#undef FUNCTION
#define FUNCTION		"gocr_moduleSetAttribute"
/**
  \brief sets the attribute of a module.

  Sets the attribute of a module, if the module exports a function to set
  its attributes. Refer to the module documentation.

  \param id The module id.
  \param a A parameter to pass to the module.
  \param b A second parameter to pass to the module.
  \return what the module attribute function returned, or -1 if there was not
    such function or module.
*/
int gocr_moduleSetAttribute ( gocr_ModuleId id, char *a, char *b ) {
	struct _gocr_lib *l;

	_gocr_printf(3, FUNCTION, "(%d, %p, %p)\n", id, a, b);

	for_each_data(&liblist) {
		l = (struct _gocr_lib *)list_get_current(&liblist);
		if (l->id == id)
			break;
	}
	end_for_each(&liblist);

	if (l->id == id) {	/* module not found */
		_gocr_printf(1, FUNCTION, 
				"Module library not found.\n");
		return -1;
	}

	if (l->setAttrib == NULL) {	/* no such function */
		_gocr_printf(1, FUNCTION, 
				"Module library doesn't have setAttrib.\n");
		return -1;
	}

	return l->setAttrib(a, b);
}

#undef FUNCTION
#define FUNCTION		"gocr_moduleGetAttributeList"
/**
  \brief gets the attribute list of a module package.

  \param id The module id.
  \return A pointer to a gocr_ModuleAttributeInfo structure, or NULL if the
  module wasn't found.
*/
const gocr_ModuleAttributeInfo *gocr_moduleGetAttributeList ( gocr_ModuleId id ) {
	struct _gocr_lib *l;

	_gocr_printf(3, FUNCTION, "(%d)\n", id);

	for_each_data(&liblist) {
		l = (struct _gocr_lib *)list_get_current(&liblist);
		if (l->id == id)
			break;
	}
	end_for_each(&liblist);

	if (l != NULL && l->id == id) {	/* module not found */
		_gocr_printf(1, FUNCTION, 
				"Module library not found.\n");
		return NULL;
	}

	return (const gocr_ModuleAttributeInfo *)l->info->attributes;
}

#undef FUNCTION
#define FUNCTION		"gocr_moduleGetFunctionList"
/**
  \brief gets the function list of a module package.

  \param id The module id.
  \return A pointer to a gocr_ModuleFunctionInfo structure, or NULL if the
  module wasn't found.
*/
const gocr_ModuleFunctionInfo *gocr_moduleGetFunctionList ( gocr_ModuleId id ) {
	struct _gocr_lib *l;

	_gocr_printf(3, FUNCTION, "(%d)\n", id);

	for_each_data(&liblist) {
		l = (struct _gocr_lib *)list_get_current(&liblist);
		if (l->id == id)
			break;
	}
	end_for_each(&liblist);

	if (l != NULL && l->id == id) {	/* module not found */
		_gocr_printf(1, FUNCTION, 
				"Module library not found.\n");
		return NULL;
	}

	return (const gocr_ModuleFunctionInfo *)l->info->functions;
}


#undef FUNCTION
#define FUNCTION		"gocr_functionInsertBefore"
/**
  \brief inserts a module function in the list.

  Inserts a function of module type t and name functionname before function id,
  and with user supplied data.

  \param functionname The name of the function.
  \param m The id of the module package that contains this function.
  \param data A pointer to the data to be passed to this function.
  \param func The id of the function that will be after the inserted one.
   If -1, appends.
  \sa gocr_functionAppend
  \return the module function id (integer >= 0), or -1 if an error occurred.
*/
gocr_ModuleFunctionId gocr_functionInsertBefore ( char *functionname,
		gocr_ModuleId mid, void *data, gocr_ModuleFunctionId func ) {
	static struct _gocr_modulefunction n;
	struct _gocr_modulefunction 	*m;
	int 				flag = 0;
	gocr_ModuleFunctionInfo		*finfo;
	int 				(*load) (const char *filename, void *data);

	_gocr_printf(3, FUNCTION, "(%s, %d, %p, %d)\n", functionname,
			mid, data, func);

	/* open module function; search the opened modules. */
	for_each_data(&liblist) {
		n.l = (struct _gocr_lib *)list_get_current(&liblist);
		if (n.l->id == mid) {
			flag++;
			_gocr_printf(3, FUNCTION, "lib: %s\n", n.l->name);
			break;
		}
	} end_for_each(&liblist);
	if (!flag) {
		/* id not found */
		return -1;
	}

	/* now find module type and open function */
	for (finfo = n.l->info->functions, flag = 0; finfo->function; finfo++) {
		if (!strcmp(functionname, finfo->function)) {
			switch (finfo->type) {
			  case imageLoader:
				load = lt_dlsym(n.l->handle, 
						functionname);
				if (load)
					gocr_imageLoad = load;
				else {
					_gocr_printf(1, FUNCTION,
						"Module function %s not found\n",
						functionname);
					return -1;
				}
			  case imageFilter:
				n.func.imageFilter = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  case blockFinder:
				n.func.blockFinder = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  case charFinder:
				n.func.charFinder = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  case charRecognizer:
				n.func.charRecognizer = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  case contextCorrection:
				n.func.contextCorrection = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  case outputFormatter:
				n.func.outputFormatter = lt_dlsym(n.l->handle,
						 functionname);
				break;
			  default:
				_gocr_printf(1, FUNCTION,
					     "Wrong module type.\n");
				return -1;
			}
			break;
		}
	}
	if (!finfo->function) { /* module not found */
		_gocr_printf(1, FUNCTION, "Module function %s not found\n",
				     functionname); 
		return -1;
	}
	if (!n.func.imageFilter) { /* I guess this test is portable */
		_gocr_printf(1, FUNCTION, "Error opening %s: %s\n",
						functionname, lt_dlerror());
		return -1;
	}

	/* fine, we found, store in memory */
	m = (struct _gocr_modulefunction *)
		malloc(sizeof(struct _gocr_modulefunction));
	if (!m) {
		_gocr_printf(1, FUNCTION, "Not enough memory\n");
		return -1;
	}

	m->l = n.l;
	m->func = n.func;
	m->name = strdup(functionname);
	if (!m->name) {
		_gocr_printf(1, FUNCTION, "Not enough memory 2\n");
		free(m);
		return -1;
	}
	m->id = _gocr_getnewfuncid(finfo->type);
	m->data = data;

	/* and add to the list! */
	if (func == -1) {
		if (list_app(&modulefunclist[finfo->type], m) == -1)
			_gocr_printf(1, FUNCTION, "List error\n");
	}
	else {
		struct _gocr_modulefunction *n;

		for_each_data(&modulefunclist[finfo->type]) {
			n = (struct _gocr_modulefunction *)
				list_get_current(&modulefunclist[finfo->type]);
			if (n->id == func)
				break;
		} end_for_each(&modulefunclist[finfo->type]);

		if (n == NULL)
			list_app(&modulefunclist[finfo->type], m);
		else
			list_ins(&modulefunclist[finfo->type], n, m);
	}

	return m->id;
}


/**
  \brief appends a module function to the list.

  Appends a function of module type t, name functionname and with user supplied
  data to the end of the module function list.

  \param t The module type.
  \param functionname The name of the function.
  \param data A pointer to the data to be passed to this function.
  \sa gocr_functionInsertBefore
  \return The module function id (integer >= 0), or -1 if an error occurred.
*/
gocr_ModuleFunctionId gocr_functionAppend ( char *functionname, 
				gocr_ModuleId mid, void *data) {
	return gocr_functionInsertBefore(functionname, mid, data, -1);
}

#undef FUNCTION
#define FUNCTION		"gocr_functionDeleteById"
/**
  \brief deletes a module function of the list.

  Deletes a module function, given its id, of the list, and returns the 
  associated data.

  \param id The module function id.
  \sa gocr_functionDeleteByName?
  \return The associated data, which should be freed by the user.
*/
void *gocr_functionDeleteById ( gocr_ModuleFunctionId id ) {
	gocr_ModuleType			t;
	struct _gocr_modulefunction	*m;
	void 				*data = NULL;

	_gocr_printf(3, FUNCTION, "gocr_functionDeleteById(%d)", id);
	t = _gocr_getfunctype(id);

	for_each_data(&modulefunclist[t]) {
		m = (struct _gocr_modulefunction *)
			list_get_current(&modulefunclist[t]);
		if (m->id == id) {
			list_del(&modulefunclist[t], m);
			if (m->name)
				free(m->name);
			data = m->data;
			free(m);
			list_lower_level(&liblist);
			return data;
		}
	} end_for_each(&modulefunclist[t]);

	_gocr_printf(1, FUNCTION, "Module function with id %d not found.\n", id);
	return NULL;
}

int gocr_runModuleFunction ( gocr_ModuleFunctionId id, ... ) {
	struct _gocr_modulefunction 	*m;
	gocr_ModuleType 		t;
	va_list 			argp;

	_gocr_printf(3, FUNCTION, "gocr_runModuleFunction(%d)", id);

	/* find function */
	t = _gocr_getfunctype(id);
	for_each_data(&modulefunclist[t]) {
		m = (struct _gocr_modulefunction *)
			list_get_current(&modulefunclist[t]);
		if (m->id == id)
			break;
	}
	end_for_each(&modulefunclist[t]);

	if (m->id != id)
		return -1;

	/* run it */
	switch (t) {
	  case imageFilter:{
		gocr_Image *src;
		gocr_Image *target;
		void *v;

		va_start(argp, id);
		src = va_arg(argp, gocr_Image *);
		target = va_arg(argp, gocr_Image *);
		v = va_arg(argp, void *);
//		m->func.imageFilter(src, target, v);
//		m->func.imageFilter(src, v);
		va_end(argp);
		}
		break;
	  case blockFinder:{
		gocr_Image *image;
		void *v;

		va_start(argp, id);
		image = va_arg(argp, gocr_Image *);
		v = va_arg(argp, void *);
		m->func.blockFinder(image, v);
		va_end(argp);
		}
		break;
	  case charFinder:{
		gocr_Block *block;
		void *v;

		va_start(argp, id);
		block = va_arg(argp, gocr_Block *);
		v = va_arg(argp, void *);
		m->func.charFinder(block, v);
		va_end(argp);
		}
		break;
	  case charRecognizer:{
		gocr_Box *box;
		void *v;

		va_start(argp, id);
		box = va_arg(argp, gocr_Box *);
		v = va_arg(argp, void *);
		m->func.charRecognizer(box, v);
		va_end(argp);
		}
		break;
	  case contextCorrection:{
		gocr_Box *box;
		void *v;

		va_start(argp, id);
		box = va_arg(argp, gocr_Box *);
		v = va_arg(argp, void *);
		m->func.contextCorrection(box, v);
		va_end(argp);
		}
		break;
	  case outputFormatter:{
		gocr_Block **blocks;
		void *v;

		va_start(argp, id);
		blocks = va_arg(argp, gocr_Block **);
		v = va_arg(argp, void *);
		m->func.outputFormatter(blocks, v);
		va_end(argp);
		}	
		break;
	default:
			break;
	}
	_gocr_printf(1, FUNCTION, "runModuleFunction: no such id\n");
	return -1;
}


#if 0
int gocr_runModuleType ( gocr_ModuleType t ) {
  struct _gocr_modulefunction *m;

  _gocr_printf(3, FUNCTION, "gocr_runModuleType(%d)\n", t);
  for_each_data(&modulefunclist[t]) {
    m = (struct _gocr_modulefunction *)list_get_current(&modulefunclist[t]);
//    m->func(m->data);
  } end_for_each(&modulefunclist[t]);
}
#endif

#undef FUNCTION
#define FUNCTION			"gocr_runAllModules"
/**
  \brief process the image.

  This function calls every module function that were added, in correct order,
  taking care of all internal problems. 

  \retval 0 OK
  \retval -1 error.
*/
int gocr_runAllModules ( void ) {
	struct _gocr_modulefunction	*m;
	gocr_Block			**blist, *block;
	gocr_Box			*box;
	int 				i = 0;

	_gocr_printf(3, FUNCTION, "()\n");
	/* lock fields */
	_data.lock = 1;

	/* image filters */
	for_each_data(&modulefunclist[imageFilter]) {
		m = (struct _gocr_modulefunction *)
			list_get_current(&modulefunclist[imageFilter]);
		_gocr_printf(3, FUNCTION, "module imageFilter:%s\n", m->name);
		m->func.imageFilter(currentimage, m->data);
	} end_for_each(&modulefunclist[imageFilter]);

	/* find blocks */
	for_each_data(&modulefunclist[blockFinder]) {
		m = (struct _gocr_modulefunction *)
			list_get_current(&modulefunclist[blockFinder]);
		_gocr_printf(3, FUNCTION, "module blockFinder:%s\n", m->name);
		m->func.blockFinder(currentimage, m->data);
	} end_for_each(&modulefunclist[blockFinder]);

	if (_data.no_block == GOCR_TRUE && list_total(&blocklist) == 0) {
		empty.x0 = empty.y0 = 0;
		empty.x1 = currentimage->width-1;
		empty.y1 = currentimage->height-1;
		empty.t = gocr_blockTypeGetByName("TEXT");
		gocr_blockAdd(&empty);
	}

	/* frame characters in each block */
	for_each_data(&blocklist) {
		currentblock = (gocr_Block *) list_get_current(&blocklist);
		for_each_data(&modulefunclist[charFinder]) {
			m = (struct _gocr_modulefunction *)
				list_get_current(&modulefunclist[charFinder]);
			_gocr_printf(3, FUNCTION, "module charFinder:%s\n",
				     m->name);
			if (m->func.charFinder((gocr_Block *)list_get_current(&blocklist), 
					m->data) == 0)	/* function took care */
				break;
		}
		end_for_each(&modulefunclist[charFinder]);

		/* fill block information */
		_gocr_blockInfoFill(currentblock);
	}
	end_for_each(&blocklist);
	
	/* recognize each character */
	for_each_data(&blocklist) {
		currentblock = (gocr_Block *) list_get_current(&blocklist);
		for_each_data(&currentblock->boxlist) {
			currentbox = (gocr_Box *) 
				list_get_current(&currentblock->boxlist);

			for_each_data(&modulefunclist[charRecognizer]) {
				m = (struct _gocr_modulefunction *)
					list_get_current(&modulefunclist
							 [charRecognizer]);
				_gocr_printf(3, FUNCTION,
					     "module charRecognizer:%s\n",
					     m->name); 
				_gocr_debug(3, gocr_printBox(currentbox);)
				if (m->func.charRecognizer(currentbox,
							   m->data)) break;
			}
			end_for_each(&modulefunclist[charRecognizer]); 

		}
		end_for_each(&currentblock->boxlist);
	}
	end_for_each(&blocklist);

#if 0
	/* do something with unrecognized characters */
	for_each_data(&blocklist) {
		currentblock = (gocr_Block *) list_get_current(&blocklist);
		for_each_data(&currentblock->boxlist) {
			for_each_data(&modulefunclist[contextCorrection]) {
				m = (struct _gocr_modulefunction *)
					list_get_current(&modulefunclist
							 [contextCorrection]);
				_gocr_printf(3, FUNCTION,
					     "module contextCorrection:%s\n",
					     m->name);
				if (m->
				    func((gocr_Box *)
					 list_get_current(&currentblock->
							  boxlist),
					 m->data)) break;
			}
			end_for_each(&modulefunclist[contextCorrection]);
		}
		end_for_each(&currentblock->boxlist);
	}
	end_for_each(&blocklist);
#endif

	/* fill the block->text field */
	for_each_data(&blocklist) {
		_gocr_blockTextFill((gocr_Block *) list_get_current(&blocklist));
	} end_for_each(&blocklist);
	
	/* output */
	/* first store the list in an array */
	blist = (gocr_Block **)malloc((list_total(&blocklist)+1) *
			sizeof(gocr_Block *));
	if (!blist) {
		_gocr_printf(1, FUNCTION, "Could not malloc list.\n");
		return -1;
	}
	for_each_data(&blocklist) {
		blist[i++] = (gocr_Block *)list_get_current(&blocklist);
	} end_for_each(&blocklist);
	blist[i] = NULL;

	/* now process it */
	for_each_data(&modulefunclist[outputFormatter]) {
		_gocr_printf(3, FUNCTION, "module outputFormatter:%s\n",
			     m->name);
		m = (struct _gocr_modulefunction *)
			list_get_current(&modulefunclist[outputFormatter]);

		m->func.outputFormatter(blist, m->data);
	} end_for_each(&modulefunclist[outputFormatter]);

	/* and free memory */
	free(blist);

	_data.lock = 0;
	return 0;
}
