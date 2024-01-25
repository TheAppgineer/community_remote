import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Community Remote',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(0x75, 0x75, 0xf3, 1.0)),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Community Remote'),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  void incrementCounter() {
    incCounter();
    notifyListeners();
  }

  int counter() {
    return getCounter();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You have pushed the button this many times:',
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: NowPlaying(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: appState.incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.shuffle),
      ),
    );
  }
}

class NowPlaying extends StatelessWidget {
  const NowPlaying({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Text(
      '${appState.counter()}',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}
