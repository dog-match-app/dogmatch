import 'package:dogmatch/app/app.dart';
import 'package:dogmatch/app/di/injection.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const DogMatchApp());
}
