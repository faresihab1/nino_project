import 'package:flutter/material.dart';
import 'package:nino/screens/login_screen.dart';
import 'package:nino/widgets/background.dart';

class Getstartedscreen extends StatelessWidget {
  const Getstartedscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Background(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset('images/bag.png'),
                ),

                const SizedBox(height: 30),

                Stack(
                  children: [
                    Image.asset('images/con_image.png'),

                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "are you ready for a \n health checkup?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color.fromRGBO(0, 145, 110, 1),
                                fontSize: 30,
                              ),
                            ),

                            const Text(
                              "Improving your life by checking \n all your cells",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 20,
                              ),
                            ),

                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(246, 251, 250, 1),
                                  foregroundColor:
                                      const Color.fromRGBO(0, 145, 110, 1),
                                ),
                                child: const Text("Get started"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
