import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp  extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home: Scaffold(appBar: AppBar(

      backgroundColor: Colors.grey,
      ),
      body: Container(
      color: Colors.deepPurple,
        child: Center(
          child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
            child: const Text(
            "Hello Dreamer!",
            textAlign: TextAlign.center,
            style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey),
          ),
          ),
          ),
          ),
      ),
    );
  }
}