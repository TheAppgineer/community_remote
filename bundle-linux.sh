#!/bin/sh
NAME=community_remote-linux-x86_64

flutter clean
flutter build linux --release
rm -rf $NAME
mkdir -p $NAME/icons
cp -r flatpak/icons/256x256 flatpak/icons/512x512 $NAME/icons
cp flatpak/com.theappgineer.community_remote.desktop flatpak/com.theappgineer.community_remote.metainfo.xml $NAME/
cp -r build/linux/x64/release/bundle/* $NAME/
tar czf $NAME.tar.gz $NAME
