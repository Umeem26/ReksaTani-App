import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static Db? _db;
  
  static Future<void> connect() async {
    try {
      String? mongoUri = dotenv.env['MONGO_URI'];
      
      if (mongoUri == null || mongoUri.isEmpty) {
        throw Exception("MONGO_URI is not set in .env file");
      }

      if (_db != null && _db!.isConnected) {
        await _db!.close();
      }

      _db = await Db.create(mongoUri);
      await _db!.open();
      
      print('Successfully connected to MongoDB Atlas!');
    } catch (e) {
      print('Error connecting to MongoDB: $e');
      rethrow;
    }
  }

  static DbCollection getCollection(String collectionName) {
    if (_db == null || !_db!.isConnected) {
      throw Exception("Database is not connected. Call MongoDatabase.connect() first.");
    }
    return _db!.collection(collectionName);
  }

  static Future<bool> ping() async {
    try {
      if (_db == null || !_db!.isConnected) {
        await connect();
      }
      await _db!.collection('users').findOne();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      print('MongoDB connection closed.');
    }
  }
}
