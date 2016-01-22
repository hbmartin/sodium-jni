#!/bin/bash

##
# Steps:
#
#   1. Build libsodium shared libraries for Android
#
#   2. Run swig to create sodium_wrap.c 
#
#   3. Run ndk-build to build our sodiumjni shared libraries for android
#      and use GCC to build for osx/linux
#
#   4. Run gradle build script

# Fail if anything returns non-zero
set -e

require_env_var() {
    if [ -z "$1" ]; then
        echo "build-libsodium.sh: ERROR: Required env variable '$2' not set."
        echo "build-libsodium.sh: Exiting!"
        exit 1
    fi
}

require_env_var "$JAVA_HOME" "JAVA_HOME"
require_env_var "$ANDROID_HOME" "ANDROID_HOME"
require_env_var "$ANDROID_NDK_HOME" "ANDROID_NDK_HOME"

# Root location of the sodium-jni project
SODIUMJNI_HOME=$(pwd)

# Location of the sodiumJNI java classes (where SWIG should put the generated files)
SODIUMJNI_SRC_ROOT="${SODIUMJNI_HOME}/app/src"

# libsodium build location
LIBSODIUM_JNI_HOME="${SODIUMJNI_HOME}/jni"

##
# Step 0
#
echo 'Step 0: installing required libs'
brew install swig automake autoconf libtool maven pcre
# TODO: apt-get instead for debian/ubuntu


##
#   Step 1
#
echo 'Step 1: Building libsodium'
cd $LIBSODIUM_JNI_HOME
./build-libsodium.sh

##
#   Step 2 
#
echo 'Step 2: Swig-ing libsodium'
cd $LIBSODIUM_JNI_HOME

SODIUMJNI_PACKAGE=com.jackwink.libsodium.jni
SODIUMJNI_JAVA_PACKAGE_ROOT=$SODIUMJNI_SRC_ROOT/main/java/com/jackwink/libsodium/jni
JAVA_LIB_INCLUDE_PATH=$JAVA_HOME/include/darwin

rm -rf $SODIUMJNI_JAVA_PACKAGE_ROOT
mkdir -p $SODIUMJNI_JAVA_PACKAGE_ROOT
export C_INCLUDE_PATH="${JAVA_HOME}/include:${JAVA_LIB_INCLUDE_PATH}:/System/Library/Frameworks/JavaVM.framework/Headers"

rm -f *.c
/usr/local/bin/swig -java -package $SODIUMJNI_PACKAGE -outdir $SODIUMJNI_JAVA_PACKAGE_ROOT sodium.i

##
#   Step 3
#
echo 'Step 3: Creating shared library'
cd $LIBSODIUM_JNI_HOME
make clean && ./configure && make && sudo make install
# For linux, we want to create a shared library for running tests on the local jvm
LIBRARY_INCLUDE_PATH=/usr/local/lib
destlib=$LIBRARY_INCLUDE_PATH/java
mkdir -p $destlib
jnilib=libsodiumjni.jnilib
echo " jnilib: $jnilib"
echo " destlib: $destlib"
# Local JVM build (OSX/Linux)
echo 'Local JVM build'
gcc -I${JAVA_HOME}/include -I${JAVA_LIB_INCLUDE_PATH} -I${JAVA_HOME}/include -I${LIBSODIUM_JNI_HOME}/libsodium/src/libsodium/include sodium_wrap.c -shared -fPIC -L${LIBSODIUM_JNI_HOME}/libsodium/src/libsodium/.libs -lsodium -o $jnilib
sudo rm -f "$destlib/$jnilib" 
sudo mv $jnilib $destlib

# Android build
echo 'Android build'
PATH=$PATH:$ANDROID_NDK_HOME
ndk-build

# do some cleanup
echo 'Cleaning up'
rm -rf $SODIUMJNI_HOME/obj
rm -rf $SODIUMJNI_SRC_ROOT/main/lib
mv $SODIUMJNI_HOME/libs $SODIUMJNI_SRC_ROOT/main/lib

##
#   Step 4
#
echo 'Step 4: gradle build'
cd $SODIUMJNI_HOME
./gradlew build

if [ $(adb devices -l | wc -l) -gt 2 ]; then
./gradlew connectedCheck 
fi

rm -rf $SODIUMJNI_HOME/build 
rm -rf $SODIUMJNI_HOME/sodiumjni-androidlib
rm $SODIUMJNI_HOME/sodiumjni-androidlib/*.aar
mv $SODIUMJNI_HOME/app/build/outputs/aar/*.aar $SODIUMJNI_HOME/sodiumjni-androidlib
rm -rf $SODIUMJNI_HOME/app/build
open $SODIUMJNI_HOME/sodiumjni-androidlib
