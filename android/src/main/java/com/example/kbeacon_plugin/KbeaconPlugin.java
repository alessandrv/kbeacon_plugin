package com.example.kbeacon_plugin;
import com.kkmcn.kbeaconlib2.KBeacon;
import androidx.annotation.NonNull;

import com.kkmcn.kbeaconlib2.KBeaconsMgr;
import com.kkmcn.kbeaconlib2.KBeaconsMgr.KBeaconMgrDelegate;
import com.kkmcn.kbeaconlib2.KBConnState;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgCommon;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgBase;
import com.kkmcn.kbeaconlib2.KBException;


import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.ArrayList;
import java.util.List;
public class KbeaconPlugin implements FlutterPlugin, MethodCallHandler, KBeaconMgrDelegate {
    private MethodChannel channel;
    private KBeaconsMgr mBeaconsMgr;
    private KBeacon mConnectedBeacon;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "kbeacon_plugin");
        channel.setMethodCallHandler(this);

        mBeaconsMgr = KBeaconsMgr.sharedBeaconManager(binding.getApplicationContext());
        mBeaconsMgr.delegate = this;
    }

  @Override
public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
        case "startScan":
            startScan(result);
            break;
        case "connectToDevice":
            String macAddress = call.argument("macAddress");
            String password = call.argument("password");  // Extract the password from the call
            connectToDevice(macAddress, password, result);
            break;
        case "changeDeviceName":
            String newName = call.argument("newName");
            changeDeviceName(newName, result);
            break;
        default:
            result.notImplemented();
            break;
    }
}

    private void startScan(Result result) {
        if (mBeaconsMgr != null) {
            int scanResult = mBeaconsMgr.startScanning();
            if (scanResult == 0) {
                result.success("Scan started successfully");
            } else {
                result.error("SCAN_FAILED", "Failed to start scanning", null);
            }
        } else {
            result.error("MANAGER_NULL", "KBeacon Manager is not initialized", null);
        }
    }

private void connectToDevice(String macAddress, String password, Result result) {
    KBeacon beacon = mBeaconsMgr.getBeacon(macAddress);
    if (beacon != null) {
        final boolean[] hasSubmittedResult = {false}; // Track whether result has been sent

        beacon.connect(password, 5000, new KBeacon.ConnStateDelegate() {
            @Override
            public void onConnStateChange(KBeacon beacon, KBConnState state, int nReason) {
                if (state == KBConnState.Connected) {
                    mConnectedBeacon = beacon;
                    if (!hasSubmittedResult[0]) {
                        result.success("Connected to " + macAddress);
                        hasSubmittedResult[0] = true; // Mark result as submitted
                    }
                } else if (state == KBConnState.Disconnected) {
                    if (!hasSubmittedResult[0]) {
                        result.error("CONNECT_FAILED", "Failed to connect to device", null);
                        hasSubmittedResult[0] = true; // Mark result as submitted
                    }
                }
            }
        });
    } else {
        result.error("DEVICE_NOT_FOUND", "Could not find device with MAC: " + macAddress, null);
    }
}

private void changeDeviceName(String newName, Result result) {
    if (mConnectedBeacon != null && mConnectedBeacon.isConnected()) {
        KBCfgCommon commonConfig = new KBCfgCommon();
        commonConfig.setName(newName);

        ArrayList<KBCfgBase> configList = new ArrayList<>();
        configList.add(commonConfig);

        mConnectedBeacon.modifyConfig(configList, new KBeacon.ActionCallback() {
            @Override
            public void onActionComplete(boolean bConfigSuccess, KBException error) {
                if (bConfigSuccess) {
                    // Successfully changed the device name
                    result.success("Device name changed to " + newName);
                    
                    // Disconnect safely after a slight delay to ensure all tasks are completed
                    new android.os.Handler().postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            if (mConnectedBeacon != null && mConnectedBeacon.isConnected()) {
                                mConnectedBeacon.disconnect();
                            }
                        }
                    }, 500);  // Adjust delay as necessary
                } else {
                    result.error("NAME_CHANGE_FAILED", "Failed to change device name", null);
                }
            }
        });
    } else {
        result.error("NO_CONNECTED_DEVICE", "No device is connected", null);
    }
}


    @Override
    public void onBeaconDiscovered(KBeacon[] beacons) {
        List<String> beaconList = new ArrayList<>();
        for (KBeacon beacon : beacons) {
            String beaconInfo = "MAC: " + beacon.getMac() + ", RSSI: " + beacon.getRssi() + ", Nome: "+ beacon.getName();
            beaconList.add(beaconInfo);
        }
        channel.invokeMethod("onScanResult", beaconList);
    }

    @Override
    public void onScanFailed(int errorCode) {
        String errorMessage = "Scan failed with error code: " + errorCode;
        channel.invokeMethod("onScanFailed", errorMessage);
    }

    @Override
    public void onCentralBleStateChang(int bleState) {
        String bleStateMessage = "Bluetooth state changed: " + bleState;
        channel.invokeMethod("onBleStateChange", bleStateMessage);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
    }
}
