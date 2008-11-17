diff -urN build-tree.old/apache2/srclib/apr/Makefile.in build-tree/apache2/srclib/apr/Makefile.in
--- build-tree.old/apache2/srclib/apr/Makefile.in	2003-09-29 12:25:11.000000000 +0100
+++ build-tree/apache2/srclib/apr/Makefile.in	2003-09-29 12:23:03.000000000 +0100
@@ -80,6 +80,13 @@
 	fi;
 	$(LIBTOOL) --mode=install cp apr-config $(DESTDIR)$(bindir)
 	chmod 755 $(DESTDIR)$(bindir)/apr-config
+
+	if [ ! -d $(DESTDIR)$(installbuilddir) ]; then \
+	    $(top_srcdir)/build/mkdir.sh $(DESTDIR)$(installbuilddir); \
+	fi
+	$(LIBTOOL) --mode=install cp $(top_srcdir)/build/find_apr.m4 \
+	    $(DESTDIR)$(installbuilddir)/find_apr.m4	
+
 	@if [ $(INSTALL_SUBDIRS) != "none" ]; then \
             for i in $(INSTALL_SUBDIRS); do \
 	        ( cd $$i ; $(MAKE) DESTDIR=$(DESTDIR) install ); \
diff -urN build-tree.old/apache2/srclib/apr-util/Makefile.in build-tree/apache2/srclib/apr-util/Makefile.in
--- build-tree.old/apache2/srclib/apr-util/Makefile.in	2003-02-17 00:16:43.000000000 +0000
+++ build-tree/apache2/srclib/apr-util/Makefile.in	2003-09-29 12:21:58.000000000 +0100
@@ -77,6 +77,12 @@
 	$(LIBTOOL) --mode=install cp apu-config $(DESTDIR)$(bindir)
 	chmod 755 $(DESTDIR)$(bindir)/apu-config
 
+	if [ ! -d $(DESTDIR)$(installbuilddir) ]; then \
+		@APR_SOURCE_DIR@/build/mkdir.sh $(DESTDIR)$(installbuilddir); \
+	fi
+	$(LIBTOOL) --mode=install cp $(top_srcdir)/build/find_apu.m4 \
+	  $(DESTDIR)$(installbuilddir)/find_apu.m4
+
 $(TARGET_LIB):
 	@objects="`find $(SUBDIRS) -name expat -prune -o -name 'gen_uri_delims.@so_ext@' -prune -o -name '*.@so_ext@' -print`"; \
 	    tmpcmd="$(LINK) @lib_target@ @EXTRA_OS_LINK@"; \
