PINKY_HOME := $(shell pwd)
SYSTEM := $(shell uname -s)
PINKY_VERSION := "0.0.1"

ifeq ($(SYSTEM),Linux)
	ifeq ($(shell grep -ic Ubuntu /etc/issue),1)
		DISTRO := Ubuntu
		YAML_LIBDIR := "/usr/lib/x86_64-linux-gnu"
		MYSQL_INCDIR := "/usr/include/mysql/"
	else ifeq ($(shell grep -ic Centos /etc/issue),1)
		DISTRO := Centos
		YAML_LIBDIR := "/usr/lib64"
		MYSQL_INCDIR := "/usr/include/mysql/"
		MYSQL_LIBDIR := "/usr/lib64/mysql/"
	else ifeq ($([[ -f /etc/inittab ]] && shell grep -ic Gentoo /etc/inittab),3)
		DISTRO := Gentoo
		YAML_LIBDIR := "/usr/lib64"
		MYSQL_INCDIR := "/usr/include/mysql/"
		MYSQL_LIBDIR := "/usr/lib64/mysql/"
	else ifeq ($(shell grep -ic DISTRIB_ID=Arch /etc/lsb-release),1)
		DISTRO := Arch
		YAML_LIBDIR := "/usr/lib"
		MYSQL_INCDIR := "/usr/include/mysql/"
		MYSQL_LIBDIR := "/usr/lib"
	endif
endif

default: ready

ready: deps ngx_openresty/nginx/sbin/nginx $(HOME)/.luarocks/bin/pinky copy_rocks
	@luarocks make --local

pinky-server: ngx_openresty/nginx/sbin/nginx $(HOME)/.luarocks/bin/pinky restart
	@luarocks make --local

deps: deps_$(SYSTEM)
	@true

package: ready pkg_$(SYSTEM)
	@true
	@echo "Check for package in /tmp"

pkg_Linux: pkg_$(DISTRO)

fpm:
	@gem install fpm --no-rdoc --no-ri

pkg_Ubuntu: fpm
	@cd /tmp && fakeroot fpm -f -s dir -t deb -C /data/pinky-server --name pinky --version $(PINKY_VERSION) --iteration 1 --depends libreadline-dev --depends libncurses5-dev --depends libpcre3-dev  --depends libssl-dev --depends perl --depends luarocks --depends luajit --depends lua5.1 --depends libmemcached-dev --depends libsasl2-dev --depends libyaml-0-2 --depends libmysqlclient-dev --after-install /data/pinky-server/bin/post-install /data/pinky-server

pkg_Centos: fpm
	@sudo yum install -y rpm-build
	@cd /tmp && fpm -f -s dir -t rpm -C /data/pinky-server --name pinky --version $(PINKY_VERSION)  --iteration 1 --depends readline-devel --depends memcached-devel --depends mysql-devel --depends openssl-devel --depends pcre-devel --depends perl --depends luarocks --depends lua --depends lua-devel --depends ncurses-devel --depends mysql --depends libyaml-devel --after-install /data/pinky-server/bin/post-install /data/pinky-server

restart:
	@./nginx/stop; ./nginx/start

submodule:
	@git submodule update --init --recursive

deps_Centos:
	@sudo yum install -y readline-devel memcached-devel mysql-devel openssl-devel pcre-devel perl luarocks lua lua-devel ncurses-devel mysql libyaml-devel

deps_Gentoo:
	@sudo emerge dev-libs/libyaml

deps_Ubuntu:
	@sudo apt-get install -y libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl luarocks luajit lua5.1 libmemcached-dev libsasl2-dev libyaml-0-2 libmysqlclient-dev libyaml-dev

deps_Arch:
	@sudo pacman -S libmysqlclient libyaml libmemcached readline lua luarocks ncurses openssl

deps_Linux: deps_$(DISTRO)

deps_Darwin:
	@true

ngx_openresty/nginx/sbin/nginx:
	@cd vendor/projects/ngx_openresty && PATH="/sbin:$(PATH)" ./configure --prefix=$(PINKY_HOME)/ngx_openresty --with-luajit --with-ld-opt=-L$(HOME)/local/lib --with-ld-opt=-L/usr/local/Cellar/pcre/8.32/lib --with-debug
	@cd vendor/projects/ngx_openresty && make
	@cd vendor/projects/ngx_openresty && make install

$(HOME)/.luarocks/bin/pinky: submodule
	@cd vendor/projects/pinky && luarocks make MYSQL_LIBDIR=$(MYSQL_LIBDIR) MYSQL_INCDIR=$(MYSQL_INCDIR) YAML_LIBDIR=$(YAML_LIBDIR) --local pinky-0.1-0.rockspec

copy_rocks: $(HOME)/.luarocks/bin/pinky
	@rsync -av $(HOME)/.luarocks/ $(PINKY_HOME)/.luarocks
	@sed -e 's#/root/#/data/pinky-server/#g'  -i /data/pinky-server/.luarocks/bin/pinky

test: ready
	@nginx/start
