#!/bin/sh
NAME=community_remote-linux-aarch64

flutter clean
flutter build linux --release
mkdir -p build/$NAME/icons
cp -r flatpak/icons/256x256 flatpak/icons/512x512 build/$NAME/icons
cp flatpak/com.theappgineer.community_remote.desktop flatpak/com.theappgineer.community_remote.metainfo.xml build/$NAME/
cp -r build/linux/arm64/release/bundle/* build/$NAME/
cd build/
tar czf $NAME.tar.gz $NAME
