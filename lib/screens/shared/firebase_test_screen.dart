import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String testStatus = "Click button to test Firebase";
  bool isLoading = false;

  Future<void> testFirebaseConnection() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Test write
      await FirebaseFirestore.instance.collection("test").add({
        "message": "Firebase is working!",
        "time": DateTime.now().toString(),
      });

      setState(() {
        testStatus = " SUCCESS: Data sent to Firebase!\nCheck your Firestore database.";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        testStatus = " ERROR: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF6E9),
      appBar: AppBar(
        title: const Text("Firebase Connection Test"),
        backgroundColor: Colors.green.shade800,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Firebase Test",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      testStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: testStatus.contains("SUCCESS")
                            ? Colors.green
                            : testStatus.contains("ERROR")
                                ? Colors.red
                                : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isLoading ? null : testFirebaseConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        "Test Firebase Connection",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "📌 If test is successful, check your Firebase Firestore console under 'test' collection.",
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
