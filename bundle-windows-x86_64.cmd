call flutter_rust_bridge_codegen generate
call flutter clean
call flutter build windows --release
call iscc windows\community_remote.iss
call 7z a -tzip build\windows\community_remote-windows-x86_64.zip build\windows\community_remote-windows-x86_64.exe
