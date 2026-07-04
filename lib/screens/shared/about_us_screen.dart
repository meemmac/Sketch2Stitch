import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF6E9),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  children: [
                    // About Us Image with centered logo
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background image
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images/Aboutus.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Logo centered on image
                        Image.asset(
                          'assets/images/transparent_logo.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const SizedBox(height: 25),

                    // Main text content
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Sketch2Stitch is a digital tailoring platform that connects customers with skilled tailors and trusted fabric retailers, all in one seamless experience. From choosing fabrics and designs to taking smart measurements and doorstep delivery, Sketch2Stitch makes custom clothing simple, personal, and accessible. Customers can design outfits their way, tailors can grow their business with verified profiles and smart tools, and retailers can showcase premium fabrics to the right audience. One platform. One workflow. Perfectly stitched results delivered to your door.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Back button (top right)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
