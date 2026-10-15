import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, this.title = 'Coming Soon'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Lottie.asset('assets/animation/coming-soon.json')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: Text(context.canPop() ? 'Go Back' : 'Go To Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
