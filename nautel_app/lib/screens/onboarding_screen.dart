import 'package:flutter/material.dart';


import 'package:nautel_app/widgets/onboarding_dialog.dart';

class OnboardingScreen extends StatelessWidget {
  static const String id = '/onboarding';
  const OnboardingScreen({Key? key}) : super(key: key);

  
  @override
  Widget build(BuildContext context) {
        double _width = MediaQuery.of(context).size.width;
    double _height = MediaQuery.of(context).size.height;
        int _gridRows = 1;
    if (_width > _height) {
      _gridRows = 2;
    } else {
      _gridRows = 1;
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
    decoration: BoxDecoration(
          color: Colors.white70,
          gradient: _gridRows > 1
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 240, 181, 178),
                    Color.fromARGB(255, 171, 200, 224)
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 240, 181, 178),
                    Color.fromARGB(255, 171, 200, 224)
                  ],
                ),
        ),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            Text(
              "Nautel App",
              style: TextStyle(
                  fontSize: 38,
                  letterSpacing: 5,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
            ),
            OnboardingDialog()
          ],
        )),
      ),
    );
  }
}
