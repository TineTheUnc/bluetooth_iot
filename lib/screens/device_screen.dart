import 'dart:async';

import 'package:bluetooth_iot/utils/extra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/snackbar.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  bool _light_status = false;
  double _light_value = 0;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  @override
  void initState() {
    super.initState();
    _connectionStateSubscription = widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = await widget.device.discoverServices();
        _services = _services.where((element) => '0x${element.uuid.str.toUpperCase()}' == "0xCD9CFC21-0ECC-42E5-BF22-48AA715CA112").toList();
        for (var element in _services[0].characteristics) {
          if ('0x${element.uuid.str.toUpperCase()}' == "0x142F29DD-B1F0-4FA8-8E55-5A2D5F3E2471"){
            List<int> value = await element.read();
            List<String> x = String.fromCharCodes(value).split(':');
            if (int.parse(x[0]) < 1){
              _light_status = false;
            }else{
              _light_status = true;
            }
            _light_value = double.parse(x[1]);
          }
        }
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });


    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription = widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      if (e is FlutterBluePlusException && e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e), success: false);
    }
  }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''), style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }


  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
          onPressed: _isConnecting ? onCancelPressed : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
          ))
    ]);
  }

  Future OnLightStatusChanged(bool value) async{
    _light_status = value;
    try {
      for (var element in _services[0].characteristics) {
        if ('0x${element.uuid.str.toUpperCase()}' == "0x66E5FFCE-AA96-4DC9-90C3-C62BBCCD29AC"){
          String x = "S:v".replaceFirst('v', _light_status ? "1" : "0");
          if (_light_status){
            await element.write(x.codeUnits, withoutResponse: element.properties.writeWithoutResponse);
          }else{
            await element.write(x.codeUnits, withoutResponse: element.properties.writeWithoutResponse);
          }
        }
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e), success: false);
    }
    setState(() {});
  }

  Future OnLightValueChanged(double value) async{
    _light_value = value;
    try {
      for (var element in _services[0].characteristics) {
        if ('0x${element.uuid.str.toUpperCase()}' == "0x66E5FFCE-AA96-4DC9-90C3-C62BBCCD29AC"){
            String x = "V:v".replaceFirst('v', value.toInt().toString());
            await element.write(x.codeUnits, withoutResponse: element.properties.writeWithoutResponse);
          }
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e), success: false);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildConnectButton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text('Device is ${_connectionState.toString().split('.')[1]}.'),

              ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Switch(value: _light_status, onChanged: OnLightStatusChanged),
              Slider(value: _light_value, max: 70,
                  label: _light_value.round().toString(),onChanged: OnLightValueChanged)
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}
