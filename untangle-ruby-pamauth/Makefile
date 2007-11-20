default: build/pam_auth.so

build/pam_auth.so: src/pam_auth.c src/extconf.rb
	@echo ">> mkdir build"
	@mkdir -p build
	@echo ">> ruby extconf.rb"
	@ruby -C build ../src/extconf.rb
	@echo ">> make -C build"
	@make -C build

clean:
	@echo ">> rm -rf build"
	@rm -rf build

