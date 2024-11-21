package com.example.kbeacon_plugin;

import androidx.annotation.NonNull;
import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import androidx.core.app.ActivityCompat;

import com.kkmcn.kbeaconlib2.KBeacon;
import com.kkmcn.kbeaconlib2.KBeacon.ConnStateDelegate;
import com.kkmcn.kbeaconlib2.KBeaconsMgr;
import com.kkmcn.kbeaconlib2.KBeaconsMgr.KBeaconMgrDelegate;
import com.kkmcn.kbeaconlib2.KBConnState;
import com.kkmcn.kbeaconlib2.KBException;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgCommon;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgBase;

import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class KbeaconPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
        PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener, KBeaconMgrDelegate, ActivityAware {

    private MethodChannel channel;
    private EventChannel eventChannel;
    private Context context;
    private Activity activity;
    private static final String TAG = "KbeaconPlugin";

    private KBeaconsMgr kBeaconsMgr;
    private KBeacon connectedBeacon;

    private PluginRegistry.ActivityResultListener activityResultListener;
    private PluginRegistry.RequestPermissionsResultListener permissionsResultListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        kBeaconsMgr = KBeaconsMgr.sharedBeaconManager(context);

        channel = new MethodChannel(binding.getBinaryMessenger(), "kbeacon_plugin");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "kbeacon_plugin_events");
        eventChannel.setStreamHandler(this);

        // Set the KBeacon manager delegate
        kBeaconsMgr.delegate = this;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }

    // ActivityAware Methods
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        this.activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        this.activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        this.activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        this.activity = null;
    }

    // EventChannel StreamHandler Methods
    @Override
    public void onListen(Object arguments, EventSink events) {
        // Implement event streaming if needed
    }

    @Override
    public void onCancel(Object arguments) {
        // Handle stream cancellation if needed
    }

    // MethodChannel MethodCallHandler
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            // KBeacon Methods
            case "startScan":
                startKBeaconScan(result);
                break;
            case "connectToDevice":
                String macAddress = call.argument("macAddress");
                String password = call.argument("password");
                connectToKBeaconDevice(macAddress, password, result);
                break;
            case "changeDeviceName":
                String newName = call.argument("newName");
                changeKBeaconDeviceName(newName, result);
                break;
            case "disconnectDevice":
                disconnectFromKBeaconDevice(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    // Permission Handling
    private void requestPermissions(PermissionCallback callback) {
        String[] permissions;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions = new String[]{Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT};
        } else {
            permissions = new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN};
        }

        List<String> permissionsToRequest = new ArrayList<>();
        for (String perm : permissions) {
            if (ActivityCompat.checkSelfPermission(activity, perm) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(perm);
            }
        }

        if (!permissionsToRequest.isEmpty()) {
            ActivityCompat.requestPermissions(activity, permissionsToRequest.toArray(new String[0]), 0);
            this.permissionsResultListener = (requestCode, perms, grantResults) -> {
                boolean granted = true;
                for (int resultCode : grantResults) {
                    if (resultCode != PackageManager.PERMISSION_GRANTED) {
                        granted = false;
                        break;
                    }
                }
                callback.onResult(granted);
                return true;
            };
        } else {
            callback.onResult(true);
        }
    }

    private interface PermissionCallback {
        void onResult(boolean granted);
    }

    // KBeacon Methods
    private void startKBeaconScan(MethodChannel.Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null);
            return;
        }

        // Request necessary permissions before starting scan
        requestPermissions(granted -> {
            if (granted) {
                int scanResult = kBeaconsMgr.startScanning();
                if (scanResult == 0) {
                    result.success("Scan started successfully");
                } else {
                    result.error("SCAN_FAILED", "Failed to start scanning", null);
                }
            } else {
                result.error("PERMISSION_DENIED", "Required permissions not granted", null);
            }
        });
    }

    private void disconnectFromKBeaconDevice(MethodChannel.Result result) {
        if (connectedBeacon != null && connectedBeacon.isConnected()) {
            connectedBeacon.disconnect();
            connectedBeacon = null;
            result.success("Device disconnected");
        } else {
            result.error("NO_CONNECTED_DEVICE", "No device is connected", null);
        }
    }

    private void connectToKBeaconDevice(String macAddress, String password, MethodChannel.Result result) {
        KBeacon beacon = kBeaconsMgr.getBeacon(macAddress);
        if (beacon != null) {
            beacon.connect(password, 5000, new ConnStateDelegate() {
                boolean hasSubmittedResult = false;

                @Override
                public void onConnStateChange(KBeacon kBeacon, KBConnState state, int nReason) {
                    if (state == KBConnState.Connected) {
                        connectedBeacon = kBeacon;
                        if (!hasSubmittedResult) {
                            result.success("Connected to " + macAddress);
                            hasSubmittedResult = true;
                        }
                    } else if (state == KBConnState.Disconnected) {
                        if (!hasSubmittedResult) {
                            result.error("CONNECT_FAILED", "Failed to connect to device", null);
                            hasSubmittedResult = true;
                        }
                    }
                }
            });
        } else {
            result.error("DEVICE_NOT_FOUND", "Could not find device with MAC: " + macAddress, null);
        }
    }

    private void changeKBeaconDeviceName(String newName, MethodChannel.Result result) {
        if (connectedBeacon != null && connectedBeacon.isConnected()) {
            KBCfgCommon commonConfig = new KBCfgCommon();
            commonConfig.setName(newName);

            ArrayList<KBCfgBase> configList = new ArrayList<>();
            configList.add(commonConfig);

            connectedBeacon.modifyConfig(configList, new KBeacon.ActionCallback() {
                @Override
                public void onActionComplete(boolean bConfigSuccess, KBException error) {
                    if (bConfigSuccess) {
                        result.success("Device name changed to " + newName);

                        // Disconnect after a delay
                        new Handler().postDelayed(() -> {
                            if (connectedBeacon != null && connectedBeacon.isConnected()) {
                                connectedBeacon.disconnect();
                            }
                        }, 500);
                    } else {
                        result.error("NAME_CHANGE_FAILED", "Failed to change device name", error != null ? error.getMessage() : null);
                    }
                }
            });
        } else {
            result.error("NO_CONNECTED_DEVICE", "No device is connected", null);
        }
    }

    // KBeacon Manager Delegate Methods
    @Override
    public void onBeaconDiscovered(KBeacon[] beacons) {
        List<String> beaconList = new ArrayList<>();
        for (KBeacon beacon : beacons) {
            String beaconInfo = "MAC: " + beacon.getMac() + ", RSSI: " + beacon.getRssi() + ", Name: " + beacon.getName();
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

    // ActivityResultListener Methods
    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (activityResultListener != null) {
            return activityResultListener.onActivityResult(requestCode, resultCode, data);
        }
        return false;
    }

    // PermissionsResultListener Methods
    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (permissionsResultListener != null) {
            return permissionsResultListener.onRequestPermissionsResult(requestCode, permissions, grantResults);
        }
        return false;
    }
}
