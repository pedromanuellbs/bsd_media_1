// screens/fg_log/history_pay.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPayPage extends StatelessWidget {
  const HistoryPayPage({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchPhotographerPurchases(
    String photographerEmail,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final usersSnap = await firestore.collection('users').get();
    List<Map<String, dynamic>> purchases = [];

    for (final userDoc in usersSnap.docs) {
      final purchasedPhotosSnap =
          await firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('purchased_photos')
              .get();

      for (final photoDoc in purchasedPhotosSnap.docs) {
        final data = photoDoc.data();
        if (data['photographerEmail'] == photographerEmail) {
          data['clientEmail'] = userDoc['email'];
          data['clientUsername'] =
              userDoc.data().containsKey('username')
                  ? userDoc['username']
                  : '-';
          purchases.add(data);
        }
      }
    }
    purchases.sort((a, b) {
      final aTime =
          a['createdAt'] is Timestamp
              ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
      final bTime =
          b['createdAt'] is Timestamp
              ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
      return bTime.compareTo(aTime);
    });
    return purchases;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Kamu belum login.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History Pembelian Foto',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPhotographerPurchases(user.email ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }
          final purchases = snapshot.data ?? [];
          if (purchases.isEmpty) {
            return const Center(
              child: Text('Belum ada pembayaran dari klien.'),
            );
          }
          return ListView.builder(
            itemCount: purchases.length,
            itemBuilder: (context, idx) {
              final pay = purchases[idx];
              final client =
                  pay['clientUsername'] ?? pay['clientEmail'] ?? 'Klien';
              final createdAt =
                  pay['createdAt'] is Timestamp
                      ? (pay['createdAt'] as Timestamp).toDate()
                      : null;
              final photoUrl = pay['photoUrl'] ?? '';
              final about = pay['about'] ?? '';
              return ListTile(
                leading:
                    photoUrl.isNotEmpty
                        ? Image.network(
                          photoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                        : const Icon(Icons.image_outlined, size: 48),
                title: Text('Pembelian oleh: $client'),
                subtitle: Text(
                  '${about.isNotEmpty ? 'Catatan: $about\n' : ''}'
                  'Tanggal: ${createdAt != null ? createdAt.toString().split('.')[0] : "-"}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
