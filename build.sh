#!/usr/bin/env bash

INSTALL_PREFIX=`pwd`/install-

prepare() {
    patch -p0 -d apr1.5 < apr_ios.patch

    cd apr1.5 && ./buildconf 
    cd ../apr-util1.5 && ./buildconf --with-apr=../apr1.5
    cd ../log4cxx && ./autogen.sh
    cd ..
}

build_mac_one() {
    SDK=macosx;
    ARCH=$1;
    MIN_VERSION="-mmacosx-version-min=10.7"
    SDK_PATH=`xcrun -sdk $SDK --show-sdk-path`
    APR_HOME=$SDK_PATH/usr
    EXT_INCLUDE="$SDK_PATH/usr/include/apr-1/"

    export CC="xcrun --sdk $SDK clang -arch $ARCH $MIN_VERSION"
    export CPP="xcrun --sdk $SDK clang -E -arch $ARCH $MIN_VERSION"
    export CFLAGS="-std=c99 -Ofast -I$EXT_INCLUDE" 
    export LDFLAGS="-stdlib=libc++ -flto"

    export CXX="xcrun --sdk $SDK clang++ -arch $ARCH $MIN_VERSION"
    export CXXCPP="xcrun --sdk $SDK clang++ -E -arch $ARCH -std=c++11 $MIN_VERSION"
    export CXXFLAGS="-Ofast -stdlib=libc++ -std=c++11 -Wno-c++11-narrowing -I$EXT_INCLUDE" 
    
    cd log4cxx
    ./configure --prefix=$INSTALL_PREFIX$ARCH/log4cxx \
        -enable-static -enable-shared \
        --with-apr=$APR_HOME --with-apr-util=$APR_HOME
    make clean && make -j8 && make install;
    cd ..;
}

build_one() {
    SDK=$1;
    ARCH=$2;
    MIN_VERSION=-mios-version-min=5.0

    echo "Build for"
    echo "SDK: $SDK, ARCH: $ARCH"
    echo "SYSTEM: $MIN_VERSION"
    export CC="xcrun --sdk $SDK clang -arch $ARCH $MIN_VERSION"
    export CPP="xcrun --sdk $SDK clang -E -arch $ARCH $MIN_VERSION"
    export CFLAGS="-std=c99 -Ofast" 
    export LDFLAGS="-flto"

    export CXX="xcrun -sdk $SDK clang++ -arch $ARCH $MIN_VERSION"
    export CXXCPP="xcrun -sdk $SDK clang++ -E -arch $ARCH -std=c++11 $MIN_VERSION"
    export CXXFLAGS="-Ofast -stdlib=libc++ -std=c++11 -Wno-c++11-narrowing" 
    
    echo "Build apr1.5 ..."
    cd apr1.5;
    ./configure --prefix=$INSTALL_PREFIX$ARCH/apr1.5 --build="i386-apple-darwin13.3.0" --host="arm-apple-darwin9" \
        -enable-static -disable-shared  --disable-dso --enable-threads \
        ac_cv_file__dev_zero="yes" \
        ac_cv_func_setpgrp_void="yes" \
        apr_cv_process_shared_works="yes" \
        apr_cv_mutex_robust_shared="no" \
        apr_cv_tcp_nodelay_with_cork="yes" \
        apr_cv_mutex_recursive="yes" \
        ac_cv_sizeof_struct_iovec="8" \
        ac_cv_func_fdatasync="no" \
        ac_cv_func_inet_addr="yes" \
        ac_cv_func_inet_network="yes"
    make clean && make -j8 && make install;
    cd ..;

    echo "Build apr-util1.5 ..."
    cd apr-util1.5
    ./configure --prefix=$INSTALL_PREFIX$ARCH/apr-util1.5 --build="i386-apple-darwin13.3.0" --host="arm-apple-darwin9" \
        --with-apr=$INSTALL_PREFIX$ARCH/apr1.5
    make clean && make -j8 && make install;
    cd ..;

    echo "Build log4cxx ..."
    cd log4cxx
    ./configure --prefix=$INSTALL_PREFIX$ARCH/log4cxx --build="i386-apple-darwin13.3.0" --host="arm-apple-darwin9" \
        --with-apr=$INSTALL_PREFIX$ARCH/apr1.5/ --with-apr-util=$INSTALL_PREFIX$ARCH/apr-util1.5/ \
        --enable-static --disable-shared \
        LDFLAGS="-stdlib=libc++ -flto"
    make clean && make -j8 && make install;
    cd ..;
}

lipo_one() {
    LIB=$1
    ALL=$(find $INSTALL_PREFIX* -name $LIB);
    if [ -z "$ALL" ]; then return -1; fi
    lipo -create $ALL -o $LIB
}

bundle() {
    SDK=$1
    OUTPUT=$SDK-output
    rm -rf $OUTPUT log4cxx-$SDK.zip
    mkdir -p $OUTPUT/lib
    for each in libapr-1.a libaprutil-1.a libexpat.a liblog4cxx.a liblog4cxx.dylib; do
        if lipo_one $each; then
            mv $each $OUTPUT/lib
        fi
    done
    cp -r ${INSTALL_PREFIX}x86_64/log4cxx/include $OUTPUT/.
    cd $OUTPUT;
    zip -r log4cxx-$SDK.zip *
    mv log4cxx-$SDK.zip ..
    cd ..
}

#prepare

rm -rf ${INSTALL_PREFIX}*
build_mac_one x86_64
build_mac_one i386

bundle macosx

rm -rf ${INSTALL_PREFIX}*
build_one iphonesimulator x86_64
build_one iphonesimulator i386

build_one iphoneos armv7
build_one iphoneos armv7s
build_one iphoneos arm64

bundle ios
