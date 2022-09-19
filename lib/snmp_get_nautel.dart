
import 'package:intl/intl.dart';
import 'package:dart_snmp/dart_snmp.dart';

import 'package:at_utils/at_logger.dart';


import 'package:at_nautel_snmp/models/transmitter_model.dart';

Future<String> displayOID(Snmp snmp, String val, int div, String measure) async {
  var oid = Oid.fromString(val); // sysDesc
  var message = await snmp.get(oid);
  var value = message.pdu.varbinds[0].value;
  var measurement = value / div;
  return measurement.toString();
}

Future<Transmitter> getOID(Snmp session, Transmitter kryz, AtSignLogger _logger) async {
  var date = DateFormat.Md().add_jms().format(DateTime.now());
  kryz.date = date;
  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.1025.291.0', 1000, ' Div Peak').then((value) async {
    _logger.info('Div Peak : $value');
    kryz.peakmodulation = value;
  });
  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.256.303.0', 1000, '      SWR').then((value) async {
    _logger.info('SWR     : $value');
    kryz.swr = value;
  });
  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.256.256.0', 1000, 'Power out').then((value) async {
    _logger.info('Power Out : $value');
    kryz.poweroutput = value;
  });
  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.256.257.0', 1000, 'Power ref').then((value) async {
    _logger.info('Power Reflected : $value');
    kryz.powerreflected = value;
  });

  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.256.271.0', 1000, 'HeatSink Temp').then((value) async {
    _logger.info('HeatSink Temp : $value');
    kryz.heatsinktemp = value;
  });

  //sleep(Duration(seconds: 1));
  await displayOID(session, '1.3.6.1.4.1.28142.1.300.256.281.0', 1, 'Fan Speed rpm').then((value) async {
    _logger.info('Fan Speed rpm : $value');
    kryz.fanspeed = value;
  });

  return kryz;
}
