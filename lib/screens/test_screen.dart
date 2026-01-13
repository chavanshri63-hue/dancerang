import 'package:flutter/material.dart';
import '../widgets/neon_app_bar.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NeonAppBar(
        title: 'DanceRang Test',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            const Text(
              'DanceRang App is Working!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Firebase integration in progress...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Builder(builder: (context) {
              const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'dancerang-733ea');
              const url = 'https://asia-south1-$projectId.cloudfunctions.net/createRazorpayOrder';
              return Column(
                children: [
                  Text('Callable URL:', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(url, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final fns = FirebaseFunctions.instanceFor(region: 'asia-south1');
                        final callable = fns.httpsCallable('createRazorpayOrder');
                        final res = await callable.call({'ping': true});
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ping ok: ${res.data}')),
                        );
                      } on FirebaseFunctionsException catch (e) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ping failed: ${e.code} ${e.details}')),
                        );
                      } catch (e) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connection test failed. Please check your settings.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Payments sanity check (ping)'),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
