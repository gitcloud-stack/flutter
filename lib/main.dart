import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/services.dart';

void main() {
  runApp(const MiniDecisionMakerApp());
}

class MiniDecisionMakerApp extends StatelessWidget {
  const MiniDecisionMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Mini Decision Maker',
      debugShowCheckedModeBanner: false,
      home: DecisionHomePage(),
    );
  }
}

class DecisionHomePage extends StatefulWidget {
  const DecisionHomePage({super.key});

  @override
  State<DecisionHomePage> createState() => _DecisionHomePageState();
}

class _DecisionHomePageState extends State<DecisionHomePage> {
  final TextEditingController _optionController = TextEditingController();
  final List<String> _options = [];
  String? _selectedOption;
  List<String> _history = [];
  int _totalDecisions = 0;
  late ConfettiController _confettiController;
  final StreamController<int?> _selectedIndex =
      StreamController<int?>.broadcast();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _optionController.dispose();
    _selectedIndex.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addOption() {
    final option = _optionController.text.trim();
    if (option.isNotEmpty) {
      setState(() {
        _options.add(option);
        _selectedIndex.add(null);
        _optionController.clear();
        _selectedOption = null; // Clear previous result on new input
      });
    }
  }

  void _makeDecision() async {
    if (_options.length > 1) {
      final index = Random().nextInt(_options.length);
      // Trigger spin only when explicitly requested by button
      await Future.delayed(const Duration(milliseconds: 300));
      _selectedIndex.add(index);

      try {
        await _audioPlayer.play(AssetSource('sounds/spin.mp3'));
      } catch (e) {
        debugPrint('Spin sound failed: $e');
      }

      await Future.delayed(const Duration(seconds: 2));
      HapticFeedback.mediumImpact();

      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _selectedOption = _options[index];
          _history.insert(0, _selectedOption!);
          _totalDecisions++;
          _saveData();
          _confettiController.play();
        });
      });
    }
  }

  void _shareResult() {
    if (_selectedOption != null) {
      Share.share("I let SpinnyWinny choose for me: $_selectedOption");
    }
  }

  void _clearAll() {
    setState(() {
      _options.clear();
      _selectedOption = null;
    });
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('decision_history', _history);
    await prefs.setInt('total_decisions', _totalDecisions);
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('decision_history');
    final count = prefs.getInt('total_decisions');
    if (saved != null) {
      setState(() {
        _history = saved;
      });
    }
    if (count != null) {
      setState(() {
        _totalDecisions = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SpinnyWinny', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              color: Colors.white70,
              onPressed: _shareResult,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              color: Colors.white70,
              onPressed: _clearAll,
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _optionController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Enter an option',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addOption(),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _addOption,
                    child: const Text('Add Option'),
                  ),
                  const SizedBox(height: 20),
                  if (_options.length == 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Only one option added.\nAdd at least 2 to spin the wheel!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  if (_options.length > 1)
                    SizedBox(
                      height: 200,
                      child: FortuneWheel(
                        // indicators: [
                        //   FortuneIndicator(
                        //     alignment: Alignment.topCenter,
                        //     child: Icon(Icons.arrow_drop_down, color: Colors.pink, size: 72),
                        //   ),
                        // ],
                        animateFirst: false,
                        selected: _selectedIndex.stream
                            .where((event) => event != null)
                            .cast<int>(),
                        items: _options
                            .map((e) => FortuneItem(child: Text(e)))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_options.length > 1)
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.casino),
                        label: const Text('Spin to Decide'),
                        onPressed: _makeDecision,
                      ),
                    ),
                  const SizedBox(height: 30),
                  if (_selectedOption != null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Selected Option:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _selectedOption!,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  const Divider(),
                  Text('Past Decisions (${_history.length})'),
                  ..._history
                      .take(5)
                      .map(
                        (h) => ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(h),
                        ),
                      ),
                  const Divider(),
                  Text('Total Decisions Made: $_totalDecisions'),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
