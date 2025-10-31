// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const QuickFixApp());
}

class QuickFixApp extends StatelessWidget {
  const QuickFixApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickFix',
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// LOGOWANIE
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    //serverClientId: '773535626217-p4k096paf34qdkcjckkotbsqhi5g0v2u.apps.googleusercontent.com', // ZMIENIONE
  );

  Future<void> _signInWithGoogle() async {
    try {
      GoogleSignInAccount? account;
      if (kIsWeb) {
        account = await _googleSignIn.signInSilently();
        if (account == null) account = await _googleSignIn.signIn();
      } else {
        account = await _googleSignIn.signIn();
      }
      if (account == null) return;

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleScreen()));
      }
    } catch (e) {
      print('Błąd logowania: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("QuickFix", style: TextStyle(fontSize: 36)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 32),
              label: const Text("Zaloguj przez Google", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }
}

// WYBÓR ROLI
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wybierz rolę")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientHome())),
              child: const Text("KLIENT"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FreelancerHome())),
              child: const Text("FREELANCER"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
              child: const Text("MAPA ZLECENIA"),
            ),
          ],
        ),
      ),
    );
  }
}

// KLIENT – DODAJ ZLECENIE
class ClientHome extends StatefulWidget {
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  Future<void> _createJob() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brak zgody na lokalizację")));
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final id = FirebaseFirestore.instance.collection('jobs').doc().id;

    await FirebaseFirestore.instance.collection('jobs').doc(id).set({
      'id': id,
      'title': _titleCtrl.text,
      'description': _descCtrl.text,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'price': double.tryParse(_priceCtrl.text) ?? 0.0,
      'clientId': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zlecenie dodane!")));
    _titleCtrl.clear();
    _descCtrl.clear();
    _priceCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Klient – Dodaj zlecenie")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Tytuł")),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Opis")),
            TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "Cena (£)"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _createJob, child: const Text("Dodaj zlecenie")),
          ],
        ),
      ),
    );
  }
}

// FREELANCER – DOSTĘPNY / PUSH
class FreelancerHome extends StatefulWidget {
  const FreelancerHome({super.key});
  @override
  State<FreelancerHome> createState() => _FreelancerHomeState();
}

class _FreelancerHomeState extends State<FreelancerHome> {
  bool isAvailable = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _setupPushNotifications();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final doc = await FirebaseFirestore.instance.collection('freelancers').doc(_userId).get();
    if (doc.exists && doc.data()?['available'] == true) {
      setState(() => isAvailable = true);
    }
  }

  Future<void> _setupPushNotifications() async {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    await FirebaseFirestore.instance.collection('freelancers').doc(_userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(message.notification?.title ?? 'Nowe zlecenie!'),
          content: Text(message.notification?.body ?? ''),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    });
  }

  Future<void> _updateLocation() async {
    if (!isAvailable || _userId == null) return;

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition();
    await FirebaseFirestore.instance.collection('freelancers').doc(_userId).set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'available': true,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Freelancer")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isAvailable ? "DOSTĘPNY TERAZ" : "NIEDOSTĘPNY",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 20),
            Switch(
              value: isAvailable,
              onChanged: (val) async {
                setState(() => isAvailable = val);
                if (val) {
                  await _updateLocation();
                } else {
                  await FirebaseFirestore.instance.collection('freelancers').doc(_userId).set({
                    'available': false,
                  }, SetOptions(merge: true));
                }
              },
              activeColor: Colors.green,
            ),
            const Text("Włącz, by otrzymywać zlecenia od ręki"),
          ],
        ),
      ),
    );
  }
}
// MAPA – ZLECENIA W PROMIENIU 5 KM
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Set<Marker> _markers = {};
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _listenToJobs();
  }

  Future<void> _getUserLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _userPosition = LatLng(pos.latitude, pos.longitude));
  }

  void _listenToJobs() {
    FirebaseFirestore.instance.collection('jobs').snapshots().listen((snapshot) {
      setState(() {
        _markers = snapshot.docs.where((doc) {
          final data = doc.data();
          final jobPos = LatLng(data['lat'], data['lng']);
          if (_userPosition == null) return true;
          final distance = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            jobPos.latitude,
            jobPos.longitude,
          );
          return distance <= 5000; // 5 km
        }).map((doc) {
          final data = doc.data();
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(data['lat'], data['lng']),
            infoWindow: InfoWindow(title: data['title'], snippet: '£${data['price']}'),
          );
        }).toSet();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapa zleceń")),
      body: _userPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _userPosition!, zoom: 12),
              markers: _markers,
              myLocationEnabled: true,
            ),
    );
  }
}