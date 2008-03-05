#JDK_HOME      ?= /opt/jdk
#ANT_HOME        = ../../downloads/output/apache-ant-1.6.5
#ANT             = JDK_HOME=$(JDK_HOME) JAVA_HOME=$(JAVA_HOME) $(ANT_HOME)/bin/ant -emacs

all:
	ant -f build-eg.xml
	cp -f dist/*.jar ../../src/downloads/
	@echo "*** don't forget to 'svn commit ../../src/downloads/' ***"

clean:
	ant -f build-eg.xml clean
