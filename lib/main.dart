import 'package:community_remote/src/rust/backend/roon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

var appState = MyAppState();

Future<void> main() async {
  await RustLib.init();
  await startRoon(cb: appState.cb);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => appState,
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
  String serverName = '';

  void cb(event) {
    if (event is RoonEvent_CoreFound) {
      serverName = event.field0;
      notifyListeners();
    }
  }

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
        title: Text('$title (${appState.serverName})'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: Browse()),
                  Expanded(flex: 5, child: Queue()),
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

class Browse extends StatelessWidget {
  const Browse({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(10),
      child: Text(
        'You have pushed the ',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class Queue extends StatelessWidget {
  const Queue({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(10),
      child: Text(
        'button this many times:',
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

    return Card(
      margin: const EdgeInsets.all(10),
      child: Text(
        '${appState.counter()}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
