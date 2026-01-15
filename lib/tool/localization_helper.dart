// 📁 將此檔案儲存為: lib/tool/localization_helper.dart

// 新增一個語言判斷工具類
class LocalizationHelper {
  // 判斷城市名稱是否為英文
  static bool isEnglishCity(String cityName) {
    // 如果城市名稱主要是英文字母,就判定為英文
    final englishChars = cityName.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    final totalChars = cityName.replaceAll(RegExp(r'[\s,]'), '').length;
    
    // 如果英文字母佔比超過 50%,就視為英文城市
    return totalChars > 0 && (englishChars / totalChars) > 0.5;
  }

  // 取得本地化文字
  static Map<String, String> getTexts(bool isEnglish) {
    return isEnglish ? _englishTexts : _chineseTexts;
  }

  // 英文文字
  static const Map<String, String> _englishTexts = {
    // Details section
    'details': 'DETAILS',
    'tempMin': 'TEMP MIN',
    'tempMax': 'TEMP MAX',
    'sunrise': 'SUNRISE',
    'sunset': 'SUNSET',
    'humidity': 'HUMIDITY',
    'wind': 'WIND',
    'feelsLike': 'FEELS LIKE',
    'uvIndex': 'UV INDEX',
    'dewPoint': 'DEW POINT',
    'windDir': 'WIND DIR',
    
    // Forecast sections
    'hourForecast': '24 HOUR FORECAST',
    'dayForecast': '5 DAY FORECAST',
    'now': 'Now',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    
    // Outfit section
    'outfitSuggestion': 'OUTFIT SUGGESTION',
    'outfitTitle': 'Today\'s Outfit',
    
    // Weather conditions
    'thunderstorm': 'Thunderstorm',
    'drizzle': 'Drizzle',
    'rain': 'Rain',
    'snow': 'Snow',
    'atmosphere': 'Mist',
    'clear': 'Clear',
    'clouds': 'Clouds',
    'fewClouds': 'Few Clouds',
    'scatteredClouds': 'Scattered Clouds',
    'brokenClouds': 'Broken Clouds',
    'overcastClouds': 'Overcast',
    
    // Days of week
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };

  // 中文文字
  static const Map<String, String> _chineseTexts = {
    // Details section
    'details': '詳細資訊',
    'tempMin': '最低溫',
    'tempMax': '最高溫',
    'sunrise': '日出',
    'sunset': '日落',
    'humidity': '濕度',
    'wind': '風速',
    'feelsLike': '體感溫度',
    'uvIndex': 'UV指數',
    'dewPoint': '露點溫度',
    'windDir': '風向',
    
    // Forecast sections
    'hourForecast': '24小時預報',
    'dayForecast': '5天預報',
    'now': '現在',
    'today': '今天',
    'tomorrow': '明天',
    
    // Outfit section
    'outfitSuggestion': '穿搭建議',
    'outfitTitle': '今日穿搭建議',
    
    // Weather conditions
    'thunderstorm': '雷雨',
    'drizzle': '毛毛雨',
    'rain': '雨天',
    'snow': '下雪',
    'atmosphere': '霧',
    'clear': '晴天',
    'clouds': '多雲',
    'fewClouds': '晴時多雲',
    'scatteredClouds': '多雲時晴',
    'brokenClouds': '多雲',
    'overcastClouds': '陰天',
    
    // Days of week
    'monday': '週一',
    'tuesday': '週二',
    'wednesday': '週三',
    'thursday': '週四',
    'friday': '週五',
    'saturday': '週六',
    'sunday': '週日',
  };

  // 取得穿搭建議文字
  static String getOutfitSuggestion(int temp, int code, bool isEnglish) {
    if (isEnglish) {
      if (code >= 200 && code < 600) return "It's raining outside, don't forget your umbrella ☔️";
      if (temp >= 30) return "It's hot! Wear light, breathable clothes ☀️";
      if (temp >= 25) return "Warm weather, a comfortable T-shirt is perfect 👕";
      if (temp >= 20) return "A bit cool, consider a light jacket 🧥";
      if (temp >= 15) return "Getting cold, wear a jacket or sweater 🧣";
      return "Cold wave! Make sure to wear a thick coat ❄️";
    } else {
      if (code >= 200 && code < 600) return "外面正在下雨,記得帶把傘出門 ☔️";
      if (temp >= 30) return "天氣炎熱,建議穿著短袖與透氣衣物 ☀️";
      if (temp >= 25) return "天氣溫暖,穿件舒適的 T-shirt 即可 👕";
      if (temp >= 20) return "稍有涼意,建議加件薄外套 🧥";
      if (temp >= 15) return "天氣變冷了,請穿著夾克或毛衣 🧣";
      return "寒流來襲!請務必穿著厚外套保暖 ❄️";
    }
  }

  // 取得星期幾的文字
  static String getDayLabel(DateTime date, bool isEnglish) {
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    DateTime targetDay = DateTime(date.year, date.month, date.day);
    
    int daysDifference = targetDay.difference(today).inDays;
    
    if (daysDifference == 0) {
      return isEnglish ? 'Today' : '今天';
    } else if (daysDifference == 1) {
      return isEnglish ? 'Tomorrow' : '明天';
    } else {
      if (isEnglish) {
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[date.weekday - 1];
      } else {
        const weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
        return weekdays[date.weekday - 1];
      }
    }
  }

  // 取得氣候區域名稱
  static String getClimateRegionName(String region, bool isEnglish) {
    if (isEnglish) {
      switch (region) {
        case 'tropical': return 'Tropical';
        case 'subtropical': return 'Subtropical';
        case 'temperate': return 'Temperate';
        case 'nordic': return 'Nordic';
        case 'arctic': return 'Arctic';
        default: return 'Temperate';
      }
    } else {
      switch (region) {
        case 'tropical': return '熱帶';
        case 'subtropical': return '亞熱帶';
        case 'temperate': return '溫帶';
        case 'nordic': return '北歐';
        case 'arctic': return '極地';
        default: return '溫帶';
      }
    }
  }

  // 🔥 新增：翻譯穿搭建議文字（從 outfit_recommendation_service 來的）
  static String translateOutfitSuggestion(String suggestion, bool isEnglish) {
    if (isEnglish) {
      // 中文 → 英文翻譯對照表
      final Map<String, String> translations = {
        '今天會下雨,記得帶傘並穿防水外套': "It's going to rain today, remember to bring an umbrella and wear a waterproof jacket",
        ',建議穿著長袖襯衫搭配毛衣': ", wear long sleeves with a sweater",
        ',建議穿著毛衣與厚外套': ", wear a sweater and thick coat",
        ',務必穿著羽絨外套保暖': ", make sure to wear a down jacket to stay warm",
        
        '體感溫度極高!建議減少外出,穿著透氣排汗短袖短褲,務必做好防曬與補水': "Extremely high heat index! Minimize outdoor activities, wear breathable short sleeves and shorts, stay hydrated and use sun protection",
        '悶熱潮濕,建議穿著吸濕排汗材質短袖與短褲,記得防曬': "Hot and humid, wear moisture-wicking short sleeves and shorts, remember sun protection",
        '天氣炎熱,穿著輕薄短袖短褲即可,建議戴帽子與太陽眼鏡防曬': "Hot weather, wear light short sleeves and shorts, recommend wearing a hat and sunglasses",
        '溫暖但潮濕,建議穿著透氣棉質短袖與輕便長褲': "Warm but humid, wear breathable cotton short sleeves and light pants",
        '天氣溫暖舒適,穿著短袖T恤與短褲或長褲即可': "Warm and comfortable, wear a T-shirt with shorts or pants",
        
        '有風微涼,建議穿著長袖襯衫並攜帶薄外套或針織外套': "Breezy and cool, wear long sleeves and bring a light jacket or cardigan",
        '早晚稍涼,建議穿著長袖襯衫,可攜帶薄外套備用': "Cool mornings and evenings, wear long sleeves, bring a light jacket just in case",
        
        '風大偏冷,建議穿著長袖襯衫+毛衣+厚外套,可加圍巾': "Windy and cold, wear long sleeves + sweater + thick coat, consider a scarf",
        '濕冷天氣,建議穿著長袖襯衫搭配毛衣或刷毛外套': "Cold and damp, wear long sleeves with a sweater or fleece jacket",
        '天氣轉涼,建議穿著長袖襯衫+毛衣,可攜帶外套': "Getting cooler, wear long sleeves + sweater, bring a coat",
        
        '寒風刺骨!建議穿著發熱衣+毛衣+厚外套+圍巾,可戴手套': "Biting cold wind! Wear thermal underwear + sweater + thick coat + scarf, consider gloves",
        '濕冷體感更冷,建議穿著發熱衣+厚毛衣+厚外套+圍巾': "Cold and damp feels colder, wear thermal underwear + thick sweater + thick coat + scarf",
        '天氣寒冷,建議穿著發熱衣+毛衣+厚外套+圍巾': "Cold weather, wear thermal underwear + sweater + thick coat + scarf",
        
        '極度寒冷!建議穿著發熱衣+厚毛衣+羽絨外套+圍巾+毛帽+手套,注意保暖': "Extremely cold! Wear thermal underwear + thick sweater + down jacket + scarf + beanie + gloves, stay warm",
        '酷寒警報!建議穿著發熱衣+厚毛衣+厚羽絨外套+厚圍巾+毛帽+厚手套,避免長時間外出': "Severe cold warning! Wear thermal underwear + thick sweater + heavy down jacket + thick scarf + beanie + thick gloves, avoid prolonged outdoor exposure",
        
        // 地區備註
        //'(當地居民對低溫較敏感)': "(Local residents are more sensitive to cold)",
        //'(海島型氣候,濕度影響體感)': "(Island climate, humidity affects comfort)",
        //'(四季分明,適應溫差)': "(Four distinct seasons, adapted to temperature changes)",
        //'(當地居民適應寒冷氣候)': "(Local residents are adapted to cold climate)",
        //'(極地氣候,居民高度適應低溫)': "(Arctic climate, residents highly adapted to extreme cold)",
      };
      
      String result = suggestion;
      for (var entry in translations.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
      return result;
      
    } else {
      // 英文 → 中文（如果需要的話）
      // 目前 outfit service 只產生中文，所以這邊直接返回
      return suggestion;
    }
  }

  // 翻譯天氣描述
  static String translateWeatherDescription(String description, bool isEnglish) {
    if (isEnglish) {
      // 如果已經是英文，直接返回
      final englishPattern = RegExp(r'^[a-zA-Z\s]+$');
      if (englishPattern.hasMatch(description)) {
        return description;
      }
      
      // 中文轉英文對照表
      final Map<String, String> translations = {
        '晴': 'Clear',
        '晴天': 'Clear',
        '多雲': 'Cloudy',
        '陰天': 'Overcast',
        '陰': 'Overcast',
        '晴時多雲': 'Partly Cloudy',
        '多雲時晴': 'Partly Cloudy',
        '雨': 'Rain',
        '小雨': 'Light Rain',
        '大雨': 'Heavy Rain',
        '雷雨': 'Thunderstorm',
        '雷陣雨': 'Thunderstorm',
        '陣雨': 'Showers',
        '毛毛雨': 'Drizzle',
        '雪': 'Snow',
        '小雪': 'Light Snow',
        '大雪': 'Heavy Snow',
        '霧': 'Mist',
        '薄霧': 'Mist',
        '霾': 'Haze',
      };
      
      // 嘗試匹配翻譯
      for (var entry in translations.entries) {
        if (description.contains(entry.key)) {
          return entry.value;
        }
      }
      
      return description; // 找不到翻譯就返回原文
    } else {
      // 如果已經是中文，直接返回
      final englishPattern = RegExp(r'^[a-zA-Z\s]+$');
      if (!englishPattern.hasMatch(description)) {
        return description;
      }
      
      // 英文轉中文對照表
      final Map<String, String> translations = {
        'clear': '晴天',
        'sunny': '晴天',
        'cloudy': '多雲',
        'clouds': '多雲',
        'overcast': '陰天',
        'partly cloudy': '晴時多雲',
        'few clouds': '晴時多雲',
        'scattered clouds': '多雲時晴',
        'broken clouds': '多雲',
        'rain': '雨天',
        'light rain': '小雨',
        'heavy rain': '大雨',
        'thunderstorm': '雷雨',
        'showers': '陣雨',
        'drizzle': '毛毛雨',
        'snow': '下雪',
        'light snow': '小雪',
        'heavy snow': '大雪',
        'mist': '霧',
        'fog': '霧',
        'haze': '霾',
      };
      
      String lowerDesc = description.toLowerCase();
      for (var entry in translations.entries) {
        if (lowerDesc.contains(entry.key)) {
          return entry.value;
        }
      }
      
      return description; // 找不到翻譯就返回原文
    }
  }

  // 翻譯風向
  static String translateWindDirection(String direction, bool isEnglish) {
    if (isEnglish) {
      // 如果已經是英文，直接返回
      final englishPattern = RegExp(r'^[a-zA-Z\s]+$');
      if (englishPattern.hasMatch(direction)) {
        return direction;
      }
      
      // 中文轉英文風向對照表
      final Map<String, String> translations = {
        '北風': 'N',
        '北': 'N',
        '東北風': 'NE',
        '東北': 'NE',
        '東風': 'E',
        '東': 'E',
        '東南風': 'SE',
        '東南': 'SE',
        '南風': 'S',
        '南': 'S',
        '西南風': 'SW',
        '西南': 'SW',
        '西風': 'W',
        '西': 'W',
        '西北風': 'NW',
        '西北': 'NW',
        '無持續風向': 'Variable',
        '偏北風': 'N',
        '偏東風': 'E',
        '偏南風': 'S',
        '偏西風': 'W',
      };
      
      for (var entry in translations.entries) {
        if (direction.contains(entry.key)) {
          return entry.value;
        }
      }
      
      return direction;
    } else {
      // 如果已經是中文，直接返回
      final englishPattern = RegExp(r'^[a-zA-Z\s]+$');
      if (!englishPattern.hasMatch(direction)) {
        return direction;
      }
      
      // 英文轉中文風向對照表
      final Map<String, String> translations = {
        'N': '北風',
        'NE': '東北風',
        'E': '東風',
        'SE': '東南風',
        'S': '南風',
        'SW': '西南風',
        'W': '西風',
        'NW': '西北風',
        'North': '北風',
        'Northeast': '東北風',
        'East': '東風',
        'Southeast': '東南風',
        'South': '南風',
        'Southwest': '西南風',
        'West': '西風',
        'Northwest': '西北風',
        'Variable': '無持續風向',
      };
      
      String upperDir = direction.toUpperCase();
      for (var entry in translations.entries) {
        if (upperDir.contains(entry.key.toUpperCase())) {
          return entry.value;
        }
      }
      
      return direction;
    }
  }
}