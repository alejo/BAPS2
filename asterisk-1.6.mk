# Based on Astfin packages/asterisk.mk, with some extra code to
# support building ipkg.  Thanks Mike Taht for the Asterisk 1.6 port.
#
# NOTE: good idea to 'make -f libssl.mk libssl' first
  
include rules.mk

ASTERISK_VERSION=1.6.0-beta1
ASTERISK_NAME=asterisk-$(ASTERISK_VERSION)
ASTERISK_DIR=$(BUILD_DIR)/$(ASTERISK_NAME)
ASTERISK_SOURCE=$(ASTERISK_NAME).tar.gz
ASTERISK_SITE=http://ftp.digium.com/pub/asterisk/releases
ASTERISK_UNZIP=zcat
TARGET_DIR=$(TOPDIR)/tmp/asterisk-$(ASTERISK_VERSION)/ipkg/asterisk

PKG_NAME:=asterisk
PKG_VERSION:=$(ASTERISK_VERSION)
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(TOPDIR)/tmp/asterisk-$(ASTERISK_VERSION)

STAGING_INC=$(STAGING_DIR)/usr/include
STAGING_LIB=$(STAGING_DIR)/usr/lib
ASTERISK_CFLAGS=-g -mfdpic -mfast-fp -ffast-math -D__FIXED_PT__ \
-D__BLACKFIN__ -I$(STAGING_INC) -fno-jump-tables
ASTERISK_LDFLAGS=-mfdpic -L$(STAGING_LIB) -lpthread -ldl
ASTERISK_CONFIGURE_OPTS=--host=bfin-linux-uclibc --disable-largefile \
--without-pwlib --without-curl CFLAGS="$(ASTERISK_CFLAGS)" \
LDFLAGS="$(ASTERISK_LDFLAGS)"

$(DL_DIR)/$(ASTERISK_SOURCE):
	mkdir -p $(DL_DIR)
	$(WGET) -P $(DL_DIR) $(ASTERISK_SITE)/$(ASTERISK_SOURCE)

$(ASTERISK_DIR)/.unpacked: $(DL_DIR)/$(ASTERISK_SOURCE) 
	$(ASTERISK_UNZIP) $(DL_DIR)/$(ASTERISK_SOURCE) | \
	tar -C $(BUILD_DIR) $(TAR_OPTIONS) -
	touch $(ASTERISK_DIR)/.unpacked
	$(PATCH_KERNEL) $(ASTERISK_DIR) patch asterisk-$(ASTERISK_VERSION).patch
	$(PATCH_KERNEL) $(ASTERISK_DIR) patch dtmf-$(ASTERISK_VERSION).patch
	$(PATCH_KERNEL) $(ASTERISK_DIR) patch speex-$(ASTERISK_VERSION).patch
	ln -sf $(BUILD_DIR)/src/codec_g729.c $(ASTERISK_DIR)/codecs
	ln -sf $(BUILD_DIR)/src/codec_speex.c-1.6 $(ASTERISK_DIR)/codecs
	ln -sf $(BUILD_DIR)/src/g729ab_codec.h $(ASTERISK_DIR)/codecs

$(ASTERISK_DIR)/.configured: $(ASTERISK_DIR)/.unpacked $(STAGING_LIB)/libgsm.a
	ln -sf $(BUILD_DIR)/patch/menuselect.makeopts-$(ASTERISK_VERSION) $(ASTERISK_DIR)/menuselect.makeopts
	cd $(ASTERISK_DIR); ./configure $(ASTERISK_CONFIGURE_OPTS)
	touch $(ASTERISK_DIR)/.configured

# optimised GSM library, rather than slow version in asterisk source

$(STAGING_LIB)/libgsm.a:
	-patch -f -p0 < patch/blackfin-gsm.patch
	make -C $(UCLINUX_DIST)/lib/blackfin-gsm \
	CC=bfin-linux-uclibc-gcc AR=bfin-linux-uclibc-ar
	cp $(UCLINUX_DIST)/lib/blackfin-gsm/gsm/lib/libgsm.a $(STAGING_LIB)
	cp $(UCLINUX_DIST)/lib/blackfin-gsm/gsm/inc/gsm.h $(STAGING_INC)

asterisk: $(ASTERISK_DIR)/.configured $(ASTERISK_DIR) 

	OPTIMIZE="-Os" ASTCFLAGS="$(ASTERISK_CFLAGS)" \
	ASTLDFLAGS="$(ASTERISK_LDFLAGS)" \
	$(MAKE) -C $(ASTERISK_DIR) NOISY_BUILD=1

	rm -Rf $(TARGET_DIR)
	mkdir -p $(TARGET_DIR)
	mkdir -p $(TARGET_DIR)/bin/
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/agi-bin
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/sounds
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/sounds/moh
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/sounds/meetme
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/sounds/voicemail
	mkdir -p $(TARGET_DIR)/var/spool/asterisk
	mkdir -p $(TARGET_DIR)/usr/lib/asterisk/modules
	ln -sf $(TARGET_DIR)/var/lib/asterisk/sounds/moh \
	$(TARGET_DIR)/var/lib/asterisk/
	ln -sf $(TARGET_DIR)/var/lib/asterisk/sounds/meetme \
	$(TARGET_DIR)/var/spool/asterisk/
	ln -sf $(TARGET_DIR)/var/lib/asterisk/sounds/voicemail \
	$(TARGET_DIR)/var/spool/asterisk/
	cp -v $(ASTERISK_DIR)/main/asterisk $(TARGET_DIR)/bin/
	ln -sf $(TARGET_DIR)/bin/asterisk $(TARGET_DIR)/bin/rasterisk
	find $(ASTERISK_DIR) -name '*.so' -exec cp -v "{}" \
	$(TARGET_DIR)/usr/lib/asterisk/modules/ \;
	$(TARGET_STRIP) $(TARGET_DIR)/bin/asterisk
	$(TARGET_STRIP) $(TARGET_DIR)/usr/lib/asterisk/modules/*.so

	#mkdir -p $(TARGET_DIR)/etc/asterisk
	#for x in $(ASTERISK_DIR)/configs/*.sample; do \
	#	cp $$x $(TARGET_DIR)/etc/asterisk/`basename $$x .sample`; \
	#done

	# Install default Asterisk conf and gsm prompt files
	# (be careful not to copy .svn files)

	mkdir -p $(TARGET_DIR)/etc/asterisk
	cp files/asterisk-defaults/etc/asterisk/*.conf $(TARGET_DIR)/etc/asterisk
	mkdir -p $(TARGET_DIR)/etc/asterisk/tools
	cp files/asterisk-defaults/etc/asterisk/tools/* $(TARGET_DIR)/etc/asterisk/tools
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/sounds
	cp files/asterisk-defaults/var/lib/asterisk/sounds/*.gsm \
	$(TARGET_DIR)/var/lib/asterisk/sounds
	mkdir -p $(TARGET_DIR)/var/lib/asterisk/static-http
	cp files/asterisk.index.html \
	$(TARGET_DIR)/var/lib/asterisk/static-http/index.html

	mkdir -p $(TARGET_DIR)/etc/init.d 
	cp files/asterisk.init $(TARGET_DIR)/etc/init.d/asterisk
	cp files/zaptel.conf.in $(TARGET_DIR)/etc/asterisk
	chmod a+x $(TARGET_DIR)/etc/init.d/asterisk

	touch $(PKG_BUILD_DIR)/.built

#---------------------------------------------------------------------------
#                     USEFUL ASTERISK MAKEFILE TARGETS     
#---------------------------------------------------------------------------

all: asterisk

asterisk-configure: $(ASTERISK_DIR)/.configured

asterisk-config: $(ASTERISK_DIR)/.configured
	$(MAKE) -C $(ASTERISK_DIR) menuconfig

asterisk-codecs:
	OPTIMIZE="-O4" ASTCFLAGS="$(ASTERISK_CFLAGS)" \
	ASTLDFLAGS="$(ASTERISK_LDFLAGS)" \
	$(MAKE) -C $(ASTERISK_DIR) codecs NOISY_BUILD=1

asterisk-pbx:
	OPTIMIZE="-O4" ASTCFLAGS="$(ASTERISK_CFLAGS)" \
	ASTLDFLAGS="$(ASTERISK_LDFLAGS)" \
	$(MAKE) -C $(ASTERISK_DIR) pbx NOISY_BUILD=1

dirclean:
	rm -rf $(ASTERISK_DIR)

#---------------------------------------------------------------------------
#                              CREATING PATCHES     
#---------------------------------------------------------------------------

# Generate patches between vanilla asterisk tar ball and our asterisk
# version.  Run this target after you have made any changes to
# asterisk to capture.

AO = asterisk-$(ASTERISK_VERSION)-orig
A = asterisk-$(ASTERISK_VERSION)

asterisk-make-patch:

        # untar original, to save time we check if the orig is already there

	if [ ! -d $(ASTERISK_DIR)-orig ] ; then \
		cd $(DL_DIR); tar xzf $(ASTERISK_SOURCE); \
		mv $(A) $(ASTERISK_DIR)-orig; \
	fi

	# glob support

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/main/config.c \
	$(A)/main/config.c \
	> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

	# turn off code that requires low memory

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/main/manager.c \
	$(A)/main/manager.c \
	>> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

	# optionally build without libssl

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/main/tcptls.c \
	$(A)/main/tcptls.c \
	>> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

	# we need Solaris type globbing (dunno why)

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/res/ael/ael.flex \
	$(A)/res/ael/ael.flex \
	>> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/res/ael/ael_lex.c \
	$(A)/res/ael/ael_lex.c \
	>> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

        # Don't build check_expr, as it breaks Blackfin build

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/utils/Makefile \
	$(A)/utils/Makefile \
	>> $(PWD)/patch/asterisk-$(ASTERISK_VERSION).patch

        # some diagnostics to measure DTMF CPU load, Asterisk 1.6
	# has fixed point DTMF code (nice), so these patches are not
	# really required.

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/channels/chan_zap.c \
	$(A)/channels/chan_zap.c \
	> $(PWD)/patch/dtmf-$(ASTERISK_VERSION).patch

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/main/dsp.c \
	$(A)/main/dsp.c \
	>> $(PWD)/patch/dtmf-$(ASTERISK_VERSION).patch

	# Make Speex work in 15 kbit/s mode, was broken by default.  This
	# is the mode that is optimised for the Blackfin.

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/main/frame.c \
	$(A)/main/frame.c \
	> $(PWD)/patch/speex-$(ASTERISK_VERSION).patch

	# disable g729 by default, as we may not have libg729.so

	-cd $(BUILD_DIR); diff -uN \
	$(AO)/configs/modules.conf.sample \
	$(A)//configs/modules.conf.sample \
	>> $(PWD)/patch/speex-$(ASTERISK_VERSION).patch

#---------------------------------------------------------------------------
#                              CREATING PACKAGE    
#---------------------------------------------------------------------------

define Package/asterisk
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Asterisk PBX
  DESCRIPTION:=\
        Asterisk is a complete PBX in software. It provides all \\\
        of the features you would expect from a PBX and more. \\\
        Asterisk does voice over IP in three protocols, and can \\\
        interoperate with almost all standards-based telephone \\\
        equipment using relatively inexpensive hardware.
  URL:=http://www.asterisk.org/
  ARCHITECTURE:=bfin-uclinux

endef

# post installation - add the sym link for auto start

define Package/asterisk/postinst
#!/bin/sh
/etc/init.d/asterisk enable
endef

# pre-remove - remove sym link

define Package/asterisk/prerm
#!/bin/sh
/etc/init.d/asterisk disable
endef

$(eval $(call BuildPackage,asterisk))

asterisk-package: asterisk $(PACKAGE_DIR)/asterisk_$(VERSION)_$(PKGARCH).ipk

