import 'dart:convert';
import 'package:http/http.dart' as http;

/// Weather data from Open-Meteo API
class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final int weatherCode;
  final String weatherDescription;
  final double precipitation;
  final int humidity;
  final double windSpeed;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.weatherCode,
    required this.weatherDescription,
    required this.precipitation,
    required this.humidity,
    required this.windSpeed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'apparentTemperature': apparentTemperature,
      'weatherCode': weatherCode,
      'weatherDescription': weatherDescription,
      'precipitation': precipitation,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      apparentTemperature: (json['apparentTemperature'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
      weatherDescription: json['weatherDescription'] as String,
      precipitation: (json['precipitation'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['windSpeed'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Get weather description from WMO weather code
  static String getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  /// Get weather impact on sales (estimated)
  String get salesImpact {
    // Good weather - people go out
    if (weatherCode <= 3 && temperature >= 10 && temperature <= 25) {
      return 'positive';
    }
    // Extreme cold or hot
    if (temperature < -10 || temperature > 30) {
      return 'negative';
    }
    // Rain/Snow - people stay in or rush
    if (weatherCode >= 61) {
      return 'negative';
    }
    return 'neutral';
  }
}

/// Service to fetch weather data from Open-Meteo API
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // Toronto coordinates
  static const double _torontoLat = 43.6532;
  static const double _torontoLon = -79.3832;

  WeatherData? _cachedWeather;
  DateTime? _cacheTime;

  /// Get current weather for Toronto
  Future<WeatherData?> getCurrentWeather() async {
    // Return cached data if less than 30 minutes old
    if (_cachedWeather != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 30) {
      return _cachedWeather;
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_torontoLat'
        '&longitude=$_torontoLon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'precipitation,weather_code,wind_speed_10m'
        '&timezone=America/Toronto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        _cachedWeather = WeatherData(
          temperature: (current['temperature_2m'] as num).toDouble(),
          apparentTemperature: (current['apparent_temperature'] as num)
              .toDouble(),
          weatherCode: current['weather_code'] as int,
          weatherDescription: WeatherData.getWeatherDescription(
            current['weather_code'] as int,
          ),
          precipitation: (current['precipitation'] as num).toDouble(),
          humidity: current['relative_humidity_2m'] as int,
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          timestamp: DateTime.now(),
        );

        _cacheTime = DateTime.now();
        return _cachedWeather;
      }
    } catch (e) {
      print('Weather API error: $e');
    }

    return null;
  }

  /// Get forecast for today
  Future<Map<String, dynamic>?> getTodayForecast() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_torontoLat'
        '&longitude=$_torontoLon'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_sum,precipitation_probability_max'
        '&timezone=America/Toronto'
        '&forecast_days=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];

        return {
          'date': daily['time'][0],
          'weatherCode': daily['weather_code'][0],
          'weatherDescription': WeatherData.getWeatherDescription(
            daily['weather_code'][0] as int,
          ),
          'maxTemperature': daily['temperature_2m_max'][0],
          'minTemperature': daily['temperature_2m_min'][0],
          'precipitationSum': daily['precipitation_sum'][0],
          'precipitationProbability': daily['precipitation_probability_max'][0],
        };
      }
    } catch (e) {
      print('Forecast API error: $e');
    }

    return null;
  }
}
