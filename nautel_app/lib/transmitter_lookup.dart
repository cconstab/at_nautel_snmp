import 'package:nautel_app/models/transmitter_model.dart';
import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

void lookupTransmitter(Transmitter transmitter, String result) async {
  var localtransmitter = Transmitter(stationName: 'stationName', frequency: 'frequency', ip: 'ip');

    localtransmitter = Transmitter.fromJson(json.decode(result));
    //print('RadioJSON' + transmitter.toString());
    transmitter.stationName = localtransmitter.stationName;
    transmitter.frequency = localtransmitter.frequency;
    transmitter.ip = localtransmitter.ip;
    transmitter.fanspeed = localtransmitter.fanspeed;
    transmitter.heatsinktemp = localtransmitter.heatsinktemp;
    transmitter.peakmodulation = localtransmitter.peakmodulation;
    transmitter.poweroutput = localtransmitter.poweroutput;
    transmitter.powerreflected = localtransmitter.powerreflected;
    transmitter.date = localtransmitter.date;
    transmitter.swr = localtransmitter.swr;
    //print(transmitter.fanspeed);
    //return transmitter;
}
