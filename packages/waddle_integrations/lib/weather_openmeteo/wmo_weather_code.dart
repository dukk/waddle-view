/// WMO weather interpretation codes (Open-Meteo).
/// See https://open-meteo.com/en/docs#weathervariables

/// English condition label for [code].
String wmoWeatherDescription(int code) {
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
      return 'Fog';
    case 48:
      return 'Depositing rime fog';
    case 51:
      return 'Light drizzle';
    case 53:
      return 'Moderate drizzle';
    case 55:
      return 'Dense drizzle';
    case 56:
      return 'Light freezing drizzle';
    case 57:
      return 'Dense freezing drizzle';
    case 61:
      return 'Slight rain';
    case 63:
      return 'Moderate rain';
    case 65:
      return 'Heavy rain';
    case 66:
      return 'Light freezing rain';
    case 67:
      return 'Heavy freezing rain';
    case 71:
      return 'Slight snow';
    case 73:
      return 'Moderate snow';
    case 75:
      return 'Heavy snow';
    case 77:
      return 'Snow grains';
    case 80:
      return 'Slight rain showers';
    case 81:
      return 'Moderate rain showers';
    case 82:
      return 'Violent rain showers';
    case 85:
      return 'Slight snow showers';
    case 86:
      return 'Heavy snow showers';
    case 95:
      return 'Thunderstorm';
    case 96:
      return 'Thunderstorm with slight hail';
    case 99:
      return 'Thunderstorm with heavy hail';
    default:
      return 'Unknown';
  }
}

/// OpenWeather-style icon suffix for [WeatherSlideWidget] (`01d`, `10d`, …).
String wmoWeatherOpenWeatherIcon(int code) {
  if (code == 0) {
    return '01d';
  }
  if (code >= 1 && code <= 3) {
    return code == 3 ? '04d' : '02d';
  }
  if (code == 45 || code == 48) {
    return '50d';
  }
  if (code >= 51 && code <= 57) {
    return '09d';
  }
  if (code >= 61 && code <= 67) {
    return '10d';
  }
  if (code >= 71 && code <= 77) {
    return '13d';
  }
  if (code >= 80 && code <= 82) {
    return '09d';
  }
  if (code >= 85 && code <= 86) {
    return '13d';
  }
  if (code >= 95) {
    return '11d';
  }
  return '01d';
}
