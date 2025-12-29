import 'package:flutter/material.dart';

/// 氣候區域類型
enum ClimateRegion {
  tropical,      // 熱帶（東南亞）
  subtropical,   // 亞熱帶（台灣、日本南部）
  temperate,     // 溫帶（日本、韓國、中國）
  nordic,        // 北歐（挪威、瑞典、芬蘭）
  arctic,        // 極地（冰島、格陵蘭）
}

/// 地區配置參數
class RegionConfig {
  final int tempOffset;        // 溫度偏移值
  final String culturalNote;   // 文化備註
  
  const RegionConfig(this.tempOffset, this.culturalNote);
}

/// 穿著建議結果
class OutfitRecommendation {
  final String suggestion;           // 建議文字
  final List<String> clothingItems;  // 服裝圖片路徑
  final ClimateRegion region;        // 氣候區域
  
  OutfitRecommendation({
    required this.suggestion,
    required this.clothingItems,
    required this.region,
  });
}

/// 穿著建議服務
class OutfitRecommendationService {
  
  // 地區溫度調整參數
  static const Map<ClimateRegion, RegionConfig> _regionConfigs = {
    ClimateRegion.tropical: RegionConfig(5, '當地居民對低溫較敏感'),
    ClimateRegion.subtropical: RegionConfig(2, '海島型氣候，濕度影響體感'),
    ClimateRegion.temperate: RegionConfig(0, '四季分明，適應溫差'),
    ClimateRegion.nordic: RegionConfig(-5, '當地居民適應寒冷氣候'),
    ClimateRegion.arctic: RegionConfig(-8, '極地氣候，居民高度適應低溫'),
  };
  
  /// 根據經緯度判斷氣候區域
  static ClimateRegion getClimateRegion(double lat, double lon) {
    // 極地（緯度 > 66.5°）
    if (lat.abs() > 66.5) return ClimateRegion.arctic;
    
    // 北歐（緯度 55-66.5°，經度在歐洲範圍）
    if (lat >= 55 && lat <= 66.5 && lon >= -10 && lon <= 30) {
      return ClimateRegion.nordic;
    }
    
    // 溫帶（緯度 35-55°）
    if (lat.abs() >= 35 && lat.abs() < 55) return ClimateRegion.temperate;
    
    // 亞熱帶（緯度 23.5-35°）
    if (lat.abs() >= 23.5 && lat.abs() < 35) return ClimateRegion.subtropical;
    
    // 熱帶（緯度 < 23.5°）
    return ClimateRegion.tropical;
  }
  
  /// 生成穿著建議
  static OutfitRecommendation getRecommendation({
    required int temperature,
    required int conditionCode,
    required int humidity,
    required double windSpeed,
    int? feelsLike,
    double? latitude,
    double? longitude,
  }) {
    // 使用體感溫度（更準確）
    final int actualFeelsLike = feelsLike ?? temperature;
    
    // 取得當前地區
    final ClimateRegion region = getClimateRegion(
      latitude ?? 25.0,   // 預設台北
      longitude ?? 121.5,
    );
    
    // 取得地區調整參數
    final RegionConfig config = _regionConfigs[region]!;
    
    // 調整後的體感溫度（根據地區）
    final int adjustedFeelsLike = actualFeelsLike + config.tempOffset;
    
    // 濕度與風速判斷
    final bool isHumid = humidity > 70;
    final bool isWindy = windSpeed > 20;
    
    // 判斷是否下雨
    final bool isRaining = conditionCode >= 200 && conditionCode < 600;
    
    String suggestion = '';
    List<String> clothingItems = [];
    
    // === 雨天處理 ===
    if (isRaining) {
      suggestion = '今天會下雨,記得帶傘並穿防水外套';
      clothingItems.add('assets/outfit/umbrella.png');
      
      if (adjustedFeelsLike >= 25) {
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/shorts.png']);
      } else if (adjustedFeelsLike >= 20) {
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/jeans.png', 'assets/outfit/light_jacket.png']);
      } else if (adjustedFeelsLike >= 15) {
        suggestion += ',建議穿著長袖襯衫搭配毛衣';
        clothingItems.addAll(['assets/outfit/hoodie.png', 'assets/outfit/jeans.png']);
      } else if (adjustedFeelsLike >= 10) {
        suggestion += ',建議穿著毛衣與厚外套';
        clothingItems.addAll(['assets/outfit/coat.png', 'assets/outfit/jeans.png', 'assets/outfit/scarf.png']);
      } else {
        suggestion += ',務必穿著羽絨外套保暖';
        clothingItems.addAll(['assets/outfit/down_jacket.png', 'assets/outfit/jeans.png', 'assets/outfit/scarf.png', 'assets/outfit/gloves.png']);
      }
      
      // 加入地區說明
      if (region == ClimateRegion.tropical || region == ClimateRegion.nordic) {
        suggestion += '\n(${config.culturalNote})';
      }
      
      return OutfitRecommendation(
        suggestion: suggestion,
        clothingItems: clothingItems,
        region: region,
      );
    }
    
    // === 非雨天處理（更精確的溫度區間） ===
    
    // 極端炎熱（35°C+）
    if (adjustedFeelsLike >= 35) {
      suggestion = '體感溫度極高!建議減少外出,穿著透氣排汗短袖短褲,務必做好防曬與補水';
      clothingItems.addAll([
        'assets/outfit/tshirt.png',
        'assets/outfit/shorts.png',
        'assets/outfit/sunglasses.png',
        'assets/outfit/cap.png'
      ]);
    }
    // 炎熱（30-34°C）
    else if (adjustedFeelsLike >= 30) {
      if (isHumid) {
        suggestion = '悶熱潮濕,建議穿著吸濕排汗材質短袖與短褲,記得防曬';
      } else {
        suggestion = '天氣炎熱,穿著輕薄短袖短褲即可,建議戴帽子與太陽眼鏡防曬';
      }
      clothingItems.addAll([
        'assets/outfit/tshirt.png',
        'assets/outfit/shorts.png',
        'assets/outfit/sunglasses.png',
        'assets/outfit/cap.png'
      ]);
    }
    // 溫暖（25-29°C）
    else if (adjustedFeelsLike >= 25) {
      if (isHumid) {
        suggestion = '溫暖但潮濕,建議穿著透氣棉質短袖與輕便長褲';
      } else {
        suggestion = '天氣溫暖舒適,穿著短袖T恤與短褲或長褲即可';
      }
      clothingItems.addAll([
        'assets/outfit/tshirt.png',
        'assets/outfit/shorts.png'
      ]);
    }
    // 舒適偏涼（20-24°C）
    else if (adjustedFeelsLike >= 20) {
      if (isWindy) {
        suggestion = '有風微涼,建議穿著長袖襯衫並攜帶薄外套或針織外套';
        clothingItems.add('assets/outfit/light_jacket.png');
      } else {
        suggestion = '早晚稍涼,建議穿著長袖襯衫,可攜帶薄外套備用';
      }
      clothingItems.addAll([
        'assets/outfit/tshirt.png',
        'assets/outfit/jeans.png',
        'assets/outfit/light_jacket.png'
      ]);
    }
    // 🔥 涼爽偏冷（15-19°C）- 你提到的情境
    else if (adjustedFeelsLike >= 15) {
      if (isWindy) {
        suggestion = '風大偏冷,建議穿著長袖襯衫+毛衣+厚外套,可加圍巾';
        clothingItems.addAll([
          'assets/outfit/coat.png',
          'assets/outfit/jeans.png',
          'assets/outfit/scarf.png'
        ]);
      } else if (isHumid) {
        suggestion = '濕冷天氣,建議穿著長袖襯衫搭配毛衣或刷毛外套';
        clothingItems.addAll([
          'assets/outfit/hoodie.png',
          'assets/outfit/jeans.png'
        ]);
      } else {
        suggestion = '天氣轉涼,建議穿著長袖襯衫+毛衣,可攜帶外套';
        clothingItems.addAll([
          'assets/outfit/hoodie.png',
          'assets/outfit/jeans.png'
        ]);
      }
    }
    // 🔥 寒冷（10-14°C）- 需要更明確
    else if (adjustedFeelsLike >= 10) {
      if (isWindy) {
        suggestion = '寒風刺骨!建議穿著發熱衣+毛衣+厚外套(如羽絨背心或風衣)+圍巾,可戴手套';
        clothingItems.addAll([
          'assets/outfit/coat.png',
          'assets/outfit/jeans.png',
          'assets/outfit/scarf.png',
          'assets/outfit/gloves.png'
        ]);
      } else if (isHumid) {
        suggestion = '濕冷體感更冷,建議穿著發熱衣+厚毛衣+厚外套+圍巾';
        clothingItems.addAll([
          'assets/outfit/coat.png',
          'assets/outfit/jeans.png',
          'assets/outfit/scarf.png'
        ]);
      } else {
        suggestion = '天氣寒冷,建議穿著發熱衣+毛衣+厚外套(如大衣或風衣)+圍巾';
        clothingItems.addAll([
          'assets/outfit/coat.png',
          'assets/outfit/jeans.png',
          'assets/outfit/scarf.png'
        ]);
      }
    }
    // 🔥 極寒（5-9°C）
    else if (adjustedFeelsLike >= 5) {
      suggestion = '極度寒冷!建議穿著發熱衣+厚毛衣+羽絨外套+圍巾+毛帽+手套,注意保暖';
      clothingItems.addAll([
        'assets/outfit/down_jacket.png',
        'assets/outfit/jeans.png',
        'assets/outfit/scarf.png',
        'assets/outfit/gloves.png'
      ]);
    }
    // 🔥 酷寒（<5°C）
    else {
      suggestion = '酷寒警報!建議穿著發熱衣+厚毛衣+厚羽絨外套+厚圍巾+毛帽+厚手套,避免長時間外出';
      clothingItems.addAll([
        'assets/outfit/down_jacket.png',
        'assets/outfit/jeans.png',
        'assets/outfit/scarf.png',
        'assets/outfit/gloves.png'
      ]);
    }
    
    // 加入地區說明（僅在極端地區顯示）
    if (region == ClimateRegion.tropical || 
        region == ClimateRegion.nordic || 
        region == ClimateRegion.arctic) {
      suggestion += '\n(${config.culturalNote})';
    }
    
    return OutfitRecommendation(
      suggestion: suggestion,
      clothingItems: clothingItems,
      region: region,
    );
  }
  
  /// 取得氣候區域圖示
  static IconData getRegionIcon(ClimateRegion region) {
    return switch (region) {
      ClimateRegion.tropical => Icons.wb_sunny,
      ClimateRegion.subtropical => Icons.wb_cloudy,
      ClimateRegion.temperate => Icons.ac_unit,
      ClimateRegion.nordic => Icons.severe_cold,
      ClimateRegion.arctic => Icons.snowing,
    };
  }
  
  /// 取得氣候區域名稱
  static String getRegionName(ClimateRegion region) {
    return switch (region) {
      ClimateRegion.tropical => '熱帶氣候',
      ClimateRegion.subtropical => '亞熱帶氣候',
      ClimateRegion.temperate => '溫帶氣候',
      ClimateRegion.nordic => '北歐氣候',
      ClimateRegion.arctic => '極地氣候',
    };
  }
}