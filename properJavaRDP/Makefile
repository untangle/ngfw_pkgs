JDK_HOME      ?= /opt/jdk
ANT_HOME        = ../../downloads/output/apache-ant-1.6.5
ANT             = JDK_HOME=$(JDK_HOME) JAVA_HOME=$(JAVA_HOME) $(ANT_HOME)/bin/ant -emacs

all:
	$(ANT) -f build-eg.xml

clean:
	$(ANT) -f build-eg.xml clean
