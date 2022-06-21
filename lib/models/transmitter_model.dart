class Transmitter {
  String stationName;
  String? frequency;
  String? ip;
  String? fanspeed;
  String? heatsinktemp;
  String? peakmodulation;
  String? poweroutput;
  String? powerreflected;
  String? swr;
  String? date;

  Transmitter(
      {required this.stationName,
      required this.frequency,
      required this.ip,
      this.fanspeed = '0',
      this.heatsinktemp = '0',
      this.peakmodulation = '0',
      this.poweroutput = '0',
      this.powerreflected = '0',
      this.date = '',
      this.swr = '0'});

  Transmitter.fromJson(Map<String, dynamic> json)
      : stationName = json['stationName'],
        frequency = json['frequency'],
        ip = json['ip'],
        fanspeed = json['fanspeed'],
        heatsinktemp = json['heatsinktemp'],
        peakmodulation = json['peakmodulation'],
        poweroutput = json['powerout'],
        powerreflected = json['powerreflected'],
        date = json['date'],
        swr = json['swr'];

  Transmitter.fromJsonLong(Map<String, dynamic> json)
      : stationName = json['"stationName"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        frequency = json['"frequency"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        ip = json['"ip"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        fanspeed = json['"fanspeed"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        heatsinktemp = json['"heatsinktemp"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        peakmodulation = json['"peakmodulation"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        poweroutput = json['"powerout"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        powerreflected = json['"powerreflected"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        date = json['"date"'].toString().replaceAll(RegExp('(^")|("\$)'), ''),
        swr = json['"swr"'].toString().replaceAll(RegExp('(^")|("\$)'), '');

  Map<String, dynamic> toJson() => {
        'stationName': stationName,
        'frequency': frequency,
        'ip': ip,
        'fanspeed': fanspeed,
        'heatsinktemp': heatsinktemp,
        'peakmodulation': peakmodulation,
        'poweroutput': poweroutput,
        'powerreflected': powerreflected,
        'date': date,
        'swr': swr,
      };

  Map<String, dynamic> toJsonLong() => {
        '"stationName"':'"$stationName"',
        '"frequency"': '"$frequency"',
        '"ip"': '"$ip"',
        '"fanspeed"': '"$fanspeed"',
        '"heatsinktemp"': '"$heatsinktemp"',
        '"peakmodulation"': '"$peakmodulation"',
        '"poweroutput"': '"$poweroutput"',
        '"powerreflected"': '"$powerreflected"',
        '"date"': '"$date"',
        '"swr"': '"$swr"',
      };
}
