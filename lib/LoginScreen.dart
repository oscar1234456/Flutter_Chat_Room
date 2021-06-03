import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomeScreen.dart';
import 'const.dart';
import 'loading.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, this.name}) : super(key: key);
  final name;

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  late SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  bool isInternet = true;
  late User currentUser;
  var subscription;

  @override
  void initState() {
    super.initState();
    print("initState");
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
          print("result: $result");
      if (result == ConnectivityResult.none) {
        print("None Internet");
        this.setState(() {
          isInternet = false;
        });
      } else {
        print("Has Internet");
        this.setState(() {
          isInternet = true;
          isSignedIn();
        });
      }
    });
  }

  @override
  dispose() {
    super.dispose();
    subscription.cancel();
    print("dispose");
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });
    prefs = await SharedPreferences.getInstance();
    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      print("Ok you is Logg");
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                HomeScreen(currentUserId: prefs.getString('id'))),
      );
    }
    this.setState(() {
      isLoading = false;
    });
  }

  Future<Null> handleSingIn() async {
    prefs = await SharedPreferences.getInstance();
    this.setState(() {
      isLoading = true;
    });
    GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    User? firebaseUser =
        (await firebaseAuth.signInWithCredential(credential)).user;
    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: firebaseUser.uid)
          .get();
      final List<DocumentSnapshot> documents = result.docs;
      if (documents != null && documents.length == 0) {
        // Update data to server if new user
        FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
          'nickname': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'chattingWith': null
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName!);
        await prefs.setString('photoUrl', currentUser.photoURL!);
      } else {
        // Write data to local documents have user informations
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('nickname', documents[0]['nickname']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
      }
      print("showToast");
      // Fluttertoast.showToast( msg: "This is Center Short Toast",
      //     toastLength: Toast.LENGTH_SHORT,
      //     gravity: ToastGravity.CENTER,
      //     timeInSecForIosWeb: 1,
      //     backgroundColor: Colors.red,
      //     textColor: Colors.white,
      //     fontSize: 18.0);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Sign in Successful!"),
      ));
      this.setState(() {
        isLoading = false;
      });
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(currentUserId: firebaseUser.uid)));
      print("------Yes you did it!-------");
    } else {
      print("fail");
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.name,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: <Widget>[
            Center(
              child: FlatButton(
                  onPressed: () => handleSingIn().catchError((err) {
                        Fluttertoast.showToast(msg: "Sign in fail2");
                        this.setState(() {
                          isLoading = false;
                        });
                      }),
                  child: Text(
                    '使用Google登入',
                    style: TextStyle(fontSize: 20.0),
                  ),
                  color: Color(0xffdd4b39),
                  highlightColor: Color(0xffff7f7f),
                  splashColor: Colors.transparent,
                  textColor: Colors.white,
                  padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)),
            ),

            // Loading
            Positioned(
              child: isLoading ? const Loading() : Container(),
            ),
            Positioned(
                child: isInternet
                    ? Container()
                    : Center(
                        child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          "目前沒有網路連線，請檢查連線",
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 26,
                              fontWeight: FontWeight.bold),
                        ),
                        constraints: BoxConstraints(
                            minWidth: double.infinity,
                            minHeight: double.infinity),
                        //color: Colors.deepOrangeAccent.withOpacity(0.8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      )))
          ],
        ));
  }
}
