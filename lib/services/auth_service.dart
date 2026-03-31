import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithGoogle() async {
    try {
      print('DEBUG AUTH: Step 1 - Menunggu Google Login UI...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('DEBUG AUTH: User membatalkan login');
        return null;
      }

      print('DEBUG AUTH: Step 2 - Mendapatkan credential Google...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('DEBUG AUTH: Step 3 - Signing in ke Firebase dengan credential...');
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        print('DEBUG AUTH: User Firebase null');
        return null;
      }

      print('DEBUG AUTH: Step 4 - Mengirim data user ke Firestore...');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      UserModel userModel;
      if (!userDoc.exists) {
        print('DEBUG AUTH: User baru terdeteksi, mendaftarkan akun baru...');
        userModel = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toJson());

        print('DEBUG AUTH: Membuat dompet default dengan ID professional...');
        // Menentukan ID Dompet baru dengan format kita
        final now = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
        final customId = 'WLT-$now-INIT';
        final walletRef = _firestore.collection('wallets').doc(customId);
        
        await walletRef.set({
          'id': customId,
          'walletName': 'Dompet Utama',
          'balance': 0.0,
          'type': 'personal',
          'members': [user.uid],
          'owner': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('DEBUG AUTH: Selamat datang kembali, ${user.displayName}');
        userModel = UserModel.fromJson(userDoc.data()!);
      }

      return userModel;
    } catch (e) {
      print('DEBUG AUTH ERROR: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
