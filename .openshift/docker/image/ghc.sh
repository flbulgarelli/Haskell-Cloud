#!/bin/sh -eu

# install prerequisites

dependencies="
  ca-certificates
  curl
  gcc
  libffi-dev
  libgmp-dev
  passwd
  zlib1g-dev
  "
#zlib-dev is only needed later by cabal-install
#installing all the prerequisites in the same layer saves time (we won't need to contact the update sites again)
#and space (we won't bloat subsequent layers with changes to the package db)
#passwd is used by the dockerfile for creating users
#we could save about 3Mb by creating users in this script and making it a build dependency instead
  
build_dependencies="
  ghc
  make
  ncurses-dev
  xz-utils
  "

apt-get update
apt-get install -y --no-install-recommends $dependencies $build_dependencies

#download ghc
echo "silent
show-error" >>~/.curlrc
echo "Downloading GHC ..."
curl https://downloads.haskell.org/~ghc/7.10-latest/ghc-7.10.1-src.tar.xz | tar xJ
cd ghc-*

#build
./configure --with-system-libffi

echo "V = 0
GhcHcOpts =
SRC_HC_OPTS = -O -H64m
HADDOCK_DOCS = NO
DYNAMIC_GHC_PROGRAMS = NO
GhcLibWays = v
GhcRTSWays = thr" > mk/build.mk

make -j$(nproc)
make install

cd /usr/local/lib/ghc*
#strip is silent, tell the user what's happening
echo "Stripping libraries ..."
find -name '*.a' -print -exec strip --strip-unneeded {} +
echo "Stripping executables ..."
ls bin/*
strip bin/*

#clean up bin
cd ../../bin
rm hp2ps runghc* ghc ghci ghc-pkg
mv ghc-pkg-* ghcpkg
mv ghci-* ghci
mv ghc-* ghc
mv ghcpkg ghc-pkg

#clean up
apt-get purge --auto-remove -y $build_dependencies
apt-get clean

#archive copyrights
cd /usr/share
gunzip copyrights.tar.gz
tar -rf copyrights.tar doc/*/copyright
gzip copyrights.tar
rm -r \
  /ghc-* \
  /var/lib/apt/lists/* \
  doc \
  man \
  locale \
  /var/log/*