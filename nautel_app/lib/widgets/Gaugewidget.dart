// ignore_for_file: unnecessary_this

import 'package:nautel_app/models/transmitter_model.dart';
import 'package:pretty_gauge/pretty_gauge.dart';
import 'package:timer_builder/timer_builder.dart';
import 'package:flutter/material.dart';

class GaugeWidget extends StatefulWidget {
  final String measurement;
  final String value;
  final int decimalPlaces;
  final String units;
  final double bottomRange;
  final double topRange;
  final Color lowColor;
  final Color medColor;
  final Color highColor;
  final double lowSector;
  final double medSector;
  final double highSector;
  final Transmitter transmitter;
  final double lastvalue;

  GaugeWidget(
      {required this.measurement,
      required this.units,
      required this.transmitter,
      required this.value,
      this.decimalPlaces = 2,
      this.lastvalue = 0,
      this.bottomRange = 0,
      this.topRange = 100,
      this.highColor = Colors.red,
      this.medColor = Colors.orange,
      this.lowColor = Colors.green,
      this.highSector = 40.0,
      this.medSector = 40.0,
      this.lowSector = 20.0});

  @override
  State<GaugeWidget> createState() => _GaugeWidgetState();
}

class _GaugeWidgetState extends State<GaugeWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double read = getValue(widget.value);
    double reading = getMeter(widget.value);
    var step = (this.widget.topRange - this.widget.bottomRange) / 1000;
    return TimerBuilder.periodic(const Duration(milliseconds: 10), builder: (context) {
      read = getValue(widget.value);
      if (reading - step > read) {
        reading = reading - step;
      } else if (reading + step < read) {
        reading = reading + step;
      } else {
        reading = read;
      }
      setMeter(widget.value, reading);

      return Stack(alignment: Alignment.bottomCenter, children: <Widget>[
        PrettyGauge(
          gaugeSize: 170,
          currentValueDecimalPlaces: widget.decimalPlaces,
          minValue: widget.bottomRange,
          maxValue: widget.topRange,
          segments: [
            GaugeSegment('Low', widget.lowSector, widget.lowColor),
            GaugeSegment('Medium', widget.medSector, widget.medColor),
            GaugeSegment('High', widget.highSector, widget.highColor),
          ],
          currentValue: reading,
          displayWidget:
              Text('${widget.measurement}', style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold)),
        ),
        Container(
            width: 50,
            height: 50,
            padding: EdgeInsets.all(10),
            child: Text(
              '${widget.units}',
              style: TextStyle(fontSize: 11,fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ))
      ]);

      // return  Text("${DateTime.now()}");
    });
  }

  double getValue(String value) {
    var result;
    switch (value) {
      case 'fanspeed':
        result = widget.transmitter.fanspeed;
        break;
      case 'heatsinktemp':
        result = widget.transmitter.heatsinktemp;
        break;
      case 'peakmodulation':
        result = widget.transmitter.peakmodulation;
        break;
      case 'poweroutput':
        result = widget.transmitter.poweroutput;
        break;
      case 'powerreflected':
        result = widget.transmitter.powerreflected;
        break;
      case 'swr':
        result = widget.transmitter.swr;
        break;
      default:
        result = "0.0";
        break;
    }
    return (double.parse(result));
  }

  double getMeter(String value) {
    var result;
    switch (value) {
      case 'fanspeed':
        result = widget.transmitter.meterFanspeed;
        break;
      case 'heatsinktemp':
        result = widget.transmitter.meterHeatsinktemp;
        break;
      case 'peakmodulation':
        result = widget.transmitter.meterPeakmodulation;
        break;
      case 'poweroutput':
        result = widget.transmitter.meterPoweroutput;
        break;
      case 'powerreflected':
        result = widget.transmitter.meterPowerreflected;
        break;
      case 'swr':
        result = widget.transmitter.meterSwr;
        break;
      default:
        result = "0.0";
        break;
    }
    return (double.parse(result));
  }

  setMeter(String value, double reading) {
    var result;
    switch (value) {
      case 'fanspeed':
        widget.transmitter.meterFanspeed = reading.toString();
        break;
      case 'heatsinktemp':
        widget.transmitter.meterHeatsinktemp = reading.toString();
        ;
        break;
      case 'peakmodulation':
        widget.transmitter.meterPeakmodulation = reading.toString();
        ;
        break;
      case 'poweroutput':
        widget.transmitter.meterPoweroutput = reading.toString();
        ;
        break;
      case 'powerreflected':
        widget.transmitter.meterPowerreflected = reading.toString();
        ;
        break;
      case 'swr':
        widget.transmitter.meterSwr = reading.toString();
        ;
        break;
      default:
        result = "0.0";
        break;
    }
  }
}
