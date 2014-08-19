#!/usr/bin/env bash

INSTALL_PREFIX=`pwd`/install-

prepare() {
    patch -p0 -d apr1.5 < apr_ios.patch

    cd apr1.5 && ./buildconf 
    cd ../apr-util1.5 && ./buildconf --with-apr=../apr1.5
    cd ../log4cxx && ./autogen.sh
    cd ..
}

build_one() {
    SDK=$1;
    ARCH=$2;
    export CC="xcrun --sdk $SDK clang -arch $ARCH -mios-version-min=5.0" 
    export CPP="xcrun --sdk $SDK clang -E -arch $ARCH -mios-version-min=5.0"
    export CFLAGS="-std=c99 -Ofast" 
    export LDFLAGS="-flto"

    export CXX="xcrun -sdk $SDK clang++ -arch $ARCH -mios-version-min=5.0" 
    export CXXCPP="xcrun -sdk $SDK clang++ -E -arch $ARCH -std=c++11 -mios-version-min=5.0" 
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
    lipo -create $ALL -o $LIB
}

bundle() {
    rm -rf output log4cxx.zip
    mkdir -p output/lib
    for each in libapr-1.a libaprutil-1.a libexpat.a liblog4cxx.a; do
        lipo_one $each;
        mv $each output/lib
    done
    cp -r ${INSTALL_PREFIX}arm64/log4cxx/include output/.
    cd output;
    zip -r log4cxx.zip *
    mv log4cxx.zip ..
    cd ..
}

prepare

build_one iphonesimulator x86_64
build_one iphonesimulator i386

build_one iphoneos armv7
build_one iphoneos armv7s
build_one iphoneos arm64

bundle
