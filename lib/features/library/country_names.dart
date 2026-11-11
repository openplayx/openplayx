/// Display names for the production countries TMDB reports as ISO 3166-1
/// codes. Uncommon codes fall back to the code itself.
String countryName(String code, String language) {
  final names = _names[code.toUpperCase()];
  if (names == null) return code;
  return switch (language) {
    'zh_Hant' || 'zh-Hant' => names.$3,
    final l when l.startsWith('zh') => names.$2,
    _ => names.$1,
  };
}

const _names = <String, (String, String, String)>{
  'US': ('United States', '美国', '美國'),
  'GB': ('United Kingdom', '英国', '英國'),
  'CN': ('China', '中国大陆', '中國大陸'),
  'HK': ('Hong Kong', '中国香港', '中國香港'),
  'TW': ('Taiwan', '中国台湾', '中國台灣'),
  'JP': ('Japan', '日本', '日本'),
  'KR': ('South Korea', '韩国', '韓國'),
  'FR': ('France', '法国', '法國'),
  'DE': ('Germany', '德国', '德國'),
  'IT': ('Italy', '意大利', '義大利'),
  'ES': ('Spain', '西班牙', '西班牙'),
  'CA': ('Canada', '加拿大', '加拿大'),
  'AU': ('Australia', '澳大利亚', '澳洲'),
  'NZ': ('New Zealand', '新西兰', '紐西蘭'),
  'IN': ('India', '印度', '印度'),
  'TH': ('Thailand', '泰国', '泰國'),
  'RU': ('Russia', '俄罗斯', '俄羅斯'),
  'SE': ('Sweden', '瑞典', '瑞典'),
  'DK': ('Denmark', '丹麦', '丹麥'),
  'NO': ('Norway', '挪威', '挪威'),
  'IE': ('Ireland', '爱尔兰', '愛爾蘭'),
  'BE': ('Belgium', '比利时', '比利時'),
  'NL': ('Netherlands', '荷兰', '荷蘭'),
  'MX': ('Mexico', '墨西哥', '墨西哥'),
  'BR': ('Brazil', '巴西', '巴西'),
  'AR': ('Argentina', '阿根廷', '阿根廷'),
  'SG': ('Singapore', '新加坡', '新加坡'),
  'MY': ('Malaysia', '马来西亚', '馬來西亞'),
  'PL': ('Poland', '波兰', '波蘭'),
  'CZ': ('Czech Republic', '捷克', '捷克'),
  'HU': ('Hungary', '匈牙利', '匈牙利'),
  'TR': ('Turkey', '土耳其', '土耳其'),
  'IL': ('Israel', '以色列', '以色列'),
  'ZA': ('South Africa', '南非', '南非'),
};
