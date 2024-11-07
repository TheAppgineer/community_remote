#!/bin/sh
flutter_rust_bridge_codegen generate
flutter clean
flutter build apk --release
