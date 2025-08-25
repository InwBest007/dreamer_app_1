import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.deepPurple,
        appBar: AppBar(
          backgroundColor: Colors.white,
      ),

      // creating and decorating a Container
      body: Center(
        child: SizedBox(
          width: 500,
          child:Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow:[
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: Offset(0, 3)
                ),
              ],
            ),

            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[

                //Title box
                SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text("Title: ",
                    style: TextStyle(
                      //fontSize: ,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
                    Flexible(
                    child: Text("I was flying with my cat",
                    style: TextStyle(
                      color: Colors.blueGrey)),
                    ) 
                  ],
                ),
            
                //Description box
                SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text("Description: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
                    Flexible(child: 
                    Text("We soared through pink clouds. It was peaceful",
                    style: TextStyle(
                      color: Colors.blueGrey)),
                    )
                  ],
                ),
            
                // Emotion tag box
                SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text("Emotion tag: ",
                    style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black
                    ),
                    ),
                    Text("💖 Wholesome",
                    style: TextStyle(
                    color: Colors.blueGrey)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}