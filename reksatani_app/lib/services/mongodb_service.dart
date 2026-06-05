import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import '../core/env/env.dart';

class MongoDatabase {
  static late Db _db;
  
  static Future<void> connect() async {
    try {
      String mongoUri = Env.mongoUri;
      
      if (mongoUri.isEmpty) {
        throw Exception("MONGO_URI is not set in Env");
      }

      _db = await Db.create(mongoUri);
      await _db.open();
      
      print('Successfully connected to MongoDB Atlas!');
    } catch (e) {
      print('Error connecting to MongoDB: $e');
      rethrow;
    }
  }

  static DbCollection getCollection(String collectionName) {
    if (!_db.isConnected) {
      throw Exception("Database is not connected. Call MongoDatabase.connect() first.");
    }
    return _db.collection(collectionName);
  }

  static Future<bool> ping() async {
    try {
      if (!_db.isConnected) {
        await connect();
      }
      await _db.collection('users').findOne();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> close() async {
    if (_db.isConnected) {
      await _db.close();
      print('MongoDB connection closed.');
    }
  }
}
