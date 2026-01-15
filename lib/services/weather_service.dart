import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WeatherData {
  final double temp;
  final String condition;
  final String description;
  final String city;

  WeatherData({
    required this.temp,
    required this.condition,
    required this.description,
    required this.city,
  });
}

class WeatherService {
  static const String _defaultApiKey = '8569c7625881c15f94b3010b99818acc'; // Demo/Fallback key - replace with user's key later

  static Future<WeatherData?> getCurrentWeather() async {
    try {
      // 1. Konum izni ve konum al
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // 2. OpenWeatherMap API çağrısı
      final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? _defaultApiKey;
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric&lang=tr';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData(
          temp: (data['main']['temp'] as num).toDouble(),
          condition: data['weather'][0]['main'],
          description: data['weather'][0]['description'],
          city: data['name'],
        );
      }
      return null;
    } catch (e) {
      debugPrint('WeatherService Error: $e');
      return null;
    }
  }
}
