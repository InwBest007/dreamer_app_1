// หน้าจอแสดงผลเอาท์พุตคำทำนายฝัน และเลขนำโชค
//import 'package:dreamer_app/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,

        // a return button
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            "ผลการทำนายความฝัน",
            style: TextStyle(color: Colors.white),
            //textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.deepPurple,
        ),

        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // returning an output of 'Dream Title'
                const SizedBox(height: 25),
                Container(
                  height: 50,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    "แสดงชื่อเรื่องความฝัน",
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                // returning an output of the dream generated pic
                const SizedBox(height: 25),
                Container(
                  height: 200, // dream pic = fixed height
                  alignment: Alignment.center, 
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    "แสดงภาพที่เจนด้วย ai",
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                // returning an output of 'Dream Interpretation'
                const SizedBox(height: 25),
                Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(
                    minHeight: 100, // for interpretation = flexible
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    "แสดงคำนายความฝัน",
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                // returning anoutput of 'Lucky Nuber'
                const SizedBox(height: 25),
                Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(
                    minHeight: 100,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    "แสดงเลขนำโชค",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
