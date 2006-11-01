#ifndef COMMON_H
#define COMMON_H
/* $Revision: 1.3 $ */


extern GtkWidget *button_Remove;

extern GtkWidget *MainWindow;
extern GtkCList *list_file;
extern GtkTable *Table;
extern GtkWidget *button_Add;
extern GtkWidget *button_Close;
extern GtkWidget *button_Setting;
extern GtkWidget *button_View;
extern GtkWidget *button_Convert;
extern GtkWidget *bar_status;
extern GtkWidget *FileSelection;

/* The Row number selected */
extern int nSelectedRow;

/**
 * Selected file
 */
extern int nFileSelected;

/* Functions */
extern void Close (GtkWidget *win,gpointer data);
extern void Convert (GtkWidget *win,gpointer data);
extern void AddFile (GtkWidget *win,gpointer data);
extern void Browse (GtkWidget *win,gpointer data);
extern void Setting (GtkWidget *win,gpointer data);
extern void RemoveFile (GtkWidget *win,gpointer data);
extern void destroy_fileSel(GtkWidget *wid,gpointer data);
extern void ViewFile(GtkWidget *wid,gpointer data);
extern void ReadSetting(void);
extern GtkWidget *MainWindow;
/* Name of the init file */
#endif







