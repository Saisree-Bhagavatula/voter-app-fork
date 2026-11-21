import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DocumentInfo {
  final int id;
  final String sourcePdf;
  final String district;
  final String districtEn;
  final String constituency;
  final String constituencyEn;
  final String mandal;
  final String mandalEn;
  final String gramPanchayat;
  final String gramPanchayatEn;
  final String wardNo;
  final int totalVoters;

  DocumentInfo({
    required this.id,
    required this.sourcePdf,
    required this.district,
    required this.districtEn,
    required this.constituency,
    required this.constituencyEn,
    required this.mandal,
    required this.mandalEn,
    required this.gramPanchayat,
    required this.gramPanchayatEn,
    required this.wardNo,
    required this.totalVoters,
  });

  factory DocumentInfo.fromMap(Map<String, dynamic> map) {
    return DocumentInfo(
      id: map['id'] as int,
      sourcePdf: (map['source_pdf'] ?? '') as String,
      district: (map['district'] ?? '') as String,
      districtEn: (map['district_en'] ?? '') as String,
      constituency: (map['constituency'] ?? '') as String,
      constituencyEn: (map['constituency_en'] ?? '') as String,
      mandal: (map['mandal'] ?? '') as String,
      mandalEn: (map['mandal_en'] ?? '') as String,
      gramPanchayat: (map['gram_panchayat'] ?? '') as String,
      gramPanchayatEn: (map['gram_panchayat_en'] ?? '') as String,
      wardNo: (map['ward_no'] ?? '') as String,
      totalVoters: (map['total_voters'] ?? 0) as int,
    );
  }
}

class VoterRecord {
  final int id;
  final String sourcePdf;
  final String sourcePages;
  final int serialNo;
  final String acSerialRef;
  final String voterName;
  final String voterNameEn;
  final String relationshipType;
  final String relativeName;
  final String relativeNameEn;
  final int? age;
  final String gender;
  final String houseNo;
  final String epicId;
  final String? photoPath;
  final bool needsVerification;
  final String verificationNotes;
  final String district;
  final String districtEn;
  final String constituency;
  final String constituencyEn;
  final String mandal;
  final String mandalEn;
  final String gramPanchayat;
  final String gramPanchayatEn;
  final String wardNo;

  VoterRecord({
    required this.id,
    required this.sourcePdf,
    required this.sourcePages,
    required this.serialNo,
    required this.acSerialRef,
    required this.voterName,
    required this.voterNameEn,
    required this.relationshipType,
    required this.relativeName,
    required this.relativeNameEn,
    required this.age,
    required this.gender,
    required this.houseNo,
    required this.epicId,
    required this.photoPath,
    required this.needsVerification,
    required this.verificationNotes,
    required this.district,
    required this.districtEn,
    required this.constituency,
    required this.constituencyEn,
    required this.mandal,
    required this.mandalEn,
    required this.gramPanchayat,
    required this.gramPanchayatEn,
    required this.wardNo,
  });

  factory VoterRecord.fromMap(Map<String, dynamic> map) {
    return VoterRecord(
      id: map['id'] as int,
      sourcePdf: (map['source_pdf'] ?? '') as String,
      sourcePages: (map['source_pages'] ?? '') as String,
      serialNo: (map['serial_no'] ?? 0) as int,
      acSerialRef: (map['ac_serial_ref'] ?? '') as String,
      voterName: (map['voter_name'] ?? '') as String,
      voterNameEn: (map['voter_name_en'] ?? '') as String,
      relationshipType: (map['relationship_type'] ?? '') as String,
      relativeName: (map['relative_name'] ?? '') as String,
      relativeNameEn: (map['relative_name_en'] ?? '') as String,
      age: map['age'] as int?,
      gender: (map['gender'] ?? 'Unknown') as String,
      houseNo: (map['house_no'] ?? '') as String,
      epicId: (map['epic_id'] ?? '') as String,
      photoPath: map['photo_path'] as String?,
      needsVerification: (map['needs_verification'] ?? 0) == 1,
      verificationNotes: (map['verification_notes'] ?? '') as String,
      district: (map['district'] ?? '') as String,
      districtEn: (map['district_en'] ?? '') as String,
      constituency: (map['constituency'] ?? '') as String,
      constituencyEn: (map['constituency_en'] ?? '') as String,
      mandal: (map['mandal'] ?? '') as String,
      mandalEn: (map['mandal_en'] ?? '') as String,
      gramPanchayat: (map['gram_panchayat'] ?? '') as String,
      gramPanchayatEn: (map['gram_panchayat_en'] ?? '') as String,
      wardNo: (map['ward_no'] ?? '') as String,
    );
  }
}

class VoterDatabase {
  VoterDatabase._();
  static final VoterDatabase instance = VoterDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, 'voters.db');
    final data = await rootBundle.load('assets/db/voters.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final file = File(dbPath);
    final shouldCopy = !await file.exists() || await file.length() != bytes.length;
    if (shouldCopy) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath, readOnly: true);
  }

  Future<List<DocumentInfo>> getDocuments() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'ward_no ASC, source_pdf ASC');
    return rows.map(DocumentInfo.fromMap).toList();
  }

  Future<List<VoterRecord>> searchVoters({
    required String query,
    String mode = 'all',
    String? sourcePdf,
    int limit = 100,
  }) async {
    final db = await database;
    final q = query.trim();

    final whereParts = <String>[];
    final args = <Object?>[];

    if (sourcePdf != null && sourcePdf.isNotEmpty) {
      whereParts.add('v.source_pdf = ?');
      args.add(sourcePdf);
    }

    if (q.isNotEmpty) {
      final qLower = q.toLowerCase();
      final qUpper = q.toUpperCase();
      if (mode == 'epic') {
        whereParts.add('UPPER(v.epic_id) LIKE ?');
        args.add('%$qUpper%');
      } else if (mode == 'name') {
        whereParts.add('(v.voter_name LIKE ? OR LOWER(v.voter_name_en) LIKE ?)');
        args.addAll(['%$q%', '%$qLower%']);
      } else if (mode == 'serial') {
        whereParts.add('CAST(v.serial_no AS TEXT) LIKE ?');
        args.add('$q%');
      } else {
        whereParts.add(
          '(v.voter_name LIKE ? OR LOWER(v.voter_name_en) LIKE ? OR UPPER(v.epic_id) LIKE ? OR v.relative_name LIKE ? OR LOWER(v.relative_name_en) LIKE ? OR CAST(v.serial_no AS TEXT) = ?)',
        );
        args.addAll(['%$q%', '%$qLower%', '%$qUpper%', '%$q%', '%$qLower%', q]);
      }
    }

    final whereClause = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT v.*, d.district, d.district_en, d.constituency, d.constituency_en,
             d.mandal, d.mandal_en, d.gram_panchayat, d.gram_panchayat_en, d.ward_no
      FROM voters v
      JOIN documents d ON v.document_id = d.id
      $whereClause
      ORDER BY v.source_pdf ASC, v.serial_no ASC
      LIMIT ?
    ''', [...args, limit]);

    return rows.map(VoterRecord.fromMap).toList();
  }
}