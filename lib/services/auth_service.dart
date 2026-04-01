import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GOOGLE SIGN IN
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // Jika bernilai null = Pengguna pencet tombol kembali / Batal
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'photoURL': userCredential.user!.photoURL,
          'role': 'user', // Default role for new Google users
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return userCredential;
    } catch (e) {
      // 2. Beri peringatan nyaring jika terjadi error (bukannya diam saja me-return null)
      throw Exception('Gagal masuk dengan Google: $e');
    }
  }

  // EMAIL SIGN UP
  Future<UserCredential?> signUpWithEmail(String email, String password, String name) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'displayName': name,
          'photoURL': null,
          'role': 'user', // Default role for email users
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        await userCredential.user!.updateDisplayName(name);
      }
      return userCredential;
    } catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // EMAIL SIGN IN
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      return userCredential;
    } catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // PASSWORD RESET
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  String _getAuthErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Email tidak terdaftar.';
        case 'wrong-password': return 'Password salah.';
        case 'email-already-in-use': return 'Email sudah digunakan.';
        case 'weak-password': return 'Password terlalu lemah.';
        case 'invalid-email': return 'Format email salah.';
        default: return 'Gagal: ${e.message ?? e.code}';
      }
    }
    return 'Terjadi kesalahan tidak terduga.';
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      // Ignore
    }
  }

  Stream<User?> get userStream => _auth.authStateChanges();

  // CHECK IF ADMIN
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists && doc.data()?['role'] == 'admin';
  }
}
