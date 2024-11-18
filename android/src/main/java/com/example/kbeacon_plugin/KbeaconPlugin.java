package com.example.kbeacon_plugin;

import androidx.annotation.NonNull;
import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.core.app.ActivityCompat;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;
import com.espressif.provisioning.DeviceConnectionEvent;

import com.espressif.provisioning.ESPConstants;
import com.espressif.provisioning.ESPDevice;
import com.espressif.provisioning.ESPProvisionManager;
import com.espressif.provisioning.listeners.BleScanListener;
import com.espressif.provisioning.listeners.ProvisionListener;
import com.espressif.provisioning.listeners.WiFiScanListener;

import com.kkmcn.kbeaconlib2.KBeacon;
import com.kkmcn.kbeaconlib2.KBeacon.ActionCallback;
import com.kkmcn.kbeaconlib2.KBeacon.ConnStateDelegate;
import com.kkmcn.kbeaconlib2.KBeaconsMgr;
import com.kkmcn.kbeaconlib2.KBeaconsMgr.KBeaconMgrDelegate;
import com.kkmcn.kbeaconlib2.KBConnState;
import com.kkmcn.kbeaconlib2.KBException;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgCommon;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgBase;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.os.ParcelUuid;
import java.util.Map;
import java.util.UUID;
import java.nio.charset.StandardCharsets;
import android.bluetooth.le.ScanSettings;

import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanRecord;
import android.os.ParcelUuid;
import java.util.List;
import java.util.Map;

import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanRecord;
import android.os.ParcelUuid;
import android.util.SparseArray;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;


public class KbeaconPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
        PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener, KBeaconMgrDelegate {

    private MethodChannel channel;
    private EventChannel eventChannel;
    private Context context;
    private Activity activity;
    private static final String TAG = "KbeaconPlugin";

    private ESPProvisionManager espProvisionManager;
    private KBeaconsMgr kBeaconsMgr;
    private KBeacon connectedBeacon;

    private Map<String, BluetoothDevice> bleDevices = new HashMap<>();
    private Map<String, String> bleDeviceServiceUuids = new HashMap<>();
    private EventSink bleScanEventSink;

    private PluginRegistry.ActivityResultListener activityResultListener;
    private PluginRegistry.RequestPermissionsResultListener permissionsResultListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        espProvisionManager = ESPProvisionManager.getInstance(context);
        kBeaconsMgr = KBeaconsMgr.sharedBeaconManager(context);

        channel = new MethodChannel(binding.getBinaryMessenger(), "kbeacon_plugin");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "flutter_esp_ble_prov/scanBleDevices");
        eventChannel.setStreamHandler(this);

        // Set the KBeacon manager delegate
        kBeaconsMgr.delegate = this;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }

    // Activity and Permission Handling
    public void setActivity(Activity activity) {
        this.activity = activity;
    }

    public void setActivityResultListener(PluginRegistry.ActivityResultListener listener) {
        this.activityResultListener = listener;
    }

    public void setPermissionsResultListener(PluginRegistry.RequestPermissionsResultListener listener) {
        this.permissionsResultListener = listener;
    }

    // EventChannel StreamHandler Methods
    @Override
    public void onListen(Object arguments, EventSink events) {
        this.bleScanEventSink = events;
        String prefix = arguments != null ? arguments.toString() : "";
        startBleScan(prefix);
    }

    @Override
    public void onCancel(Object arguments) {
        stopBleScan();
    }

    // MethodChannel MethodCallHandler
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            // ESP BLE Provisioning Methods
            case "scanBleDevices":
                String prefix = call.argument("prefix");
                scanBleDevices(prefix, result);
                break;
            case "scanWifiNetworks":
                String deviceName = call.argument("deviceName");
                String pop = call.argument("proofOfPossession");
                scanWifiNetworks(deviceName, pop, result);
                break;
            case "provisionWifi":
                deviceName = call.argument("deviceName");
                pop = call.argument("proofOfPossession");
                String ssid = call.argument("ssid");
                String passphrase = call.argument("passphrase");
                provisionWifi(deviceName, pop, ssid, passphrase, result);
                break;
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

    private String bytesToHex(byte[] bytes) {
    if (bytes == null) {
        return "null";
    }
    StringBuilder sb = new StringBuilder();
    for (byte b : bytes) {
        sb.append(String.format("%02X", b));
    }
    return sb.toString();
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
                callback.onResult(true);
                return true;
            };
        } else {
            callback.onResult(true);
        }
    }

    private interface PermissionCallback {
        void onResult(boolean granted);
    }

    // ESP BLE Provisioning Methods
    private void scanBleDevices(String prefix, MethodChannel.Result result) {
        requestPermissions(granted -> {
            if (granted) {
                startBleScan(prefix);
                result.success(null);
            } else {
                result.error("PERMISSION_DENIED", "Required permissions not granted", null);
            }
        });
    }

    @SuppressLint("MissingPermission")
    private void startBleScan(String prefix) {
        espProvisionManager.searchBleEspDevices(prefix, new BleScanListener() {
            @Override
            public void scanStartFailed() {
                if (bleScanEventSink != null) {
                    bleScanEventSink.error("SCAN_FAILED", "Scan failed to start", null);
                }
            }

            @Override
public void onPeripheralFound(BluetoothDevice device, ScanResult scanResult) {
    if (scanResult != null && scanResult.getScanRecord() != null) {
        // Get the scan record
        ScanRecord scanRecord = scanResult.getScanRecord();

        // Check if service UUIDs are available
        List<ParcelUuid> serviceUuids = scanRecord.getServiceUuids();
        String serviceUuidString = "No service UUIDs";

        if (serviceUuids != null && !serviceUuids.isEmpty()) {
            // Get the first service UUID as a string
            serviceUuidString = serviceUuids.get(0).toString();
        }

        // Extract service data (if available)
        byte[] serviceData = null;
        if (scanRecord.getServiceData() != null && !scanRecord.getServiceData().isEmpty()) {
            Map.Entry<ParcelUuid, byte[]> entry = scanRecord.getServiceData().entrySet().iterator().next();
            serviceData = entry.getValue();
        }

        String asciiMessage = serviceData != null ? new String(serviceData) : "No service data";

        // Prepare log message
        String result = "Device: " + (device.getName() == null ? "Unknown" : device.getName())
                + ", RSSI: " + scanResult.getRssi()
                + ", Service UUID: " + serviceUuidString
                + ", Service Data: " + asciiMessage;

        // Log the result
        Log.d("KbeaconPlugin", result);

        // Send to Flutter (if EventSink is active)
        if (bleScanEventSink != null) {
            bleScanEventSink.success(result);
        }
    } else {
        Log.w("KbeaconPlugin", "Scan result or scan record is null.");
    }
}


            @Override
            public void scanCompleted() {
                if (bleScanEventSink != null) {
                    bleScanEventSink.endOfStream();
                }
            }

            @Override
            public void onFailure(Exception e) {
                if (bleScanEventSink != null) {
                    bleScanEventSink.error("SCAN_FAILED", "Scan failed", e.getMessage());
                }
            }
        });
    }

    private void stopBleScan() {
        espProvisionManager.stopBleScan();
    }
private void scanWifiNetworks(String deviceName, String proofOfPossession, MethodChannel.Result result) {
    BluetoothDevice device = bleDevices.get(deviceName);
    String serviceUuid = bleDeviceServiceUuids.get(deviceName);

    if (device == null || serviceUuid == null) {
        result.error("DEVICE_NOT_FOUND", "Device not found", null);
        return;
    }

    ESPDevice espDevice = espProvisionManager.createESPDevice(ESPConstants.TransportType.TRANSPORT_BLE, ESPConstants.SecurityType.SECURITY_1);

    // Create an event subscriber
    Object eventSubscriber = new Object() {
        @Subscribe(threadMode = ThreadMode.MAIN)
        public void onEvent(DeviceConnectionEvent event) {
            if (event.getEventType() == ESPConstants.EVENT_DEVICE_CONNECTED) {
                // Unregister the subscriber
                EventBus.getDefault().unregister(this);

                // Set the proof of possession
                espDevice.setProofOfPossession(proofOfPossession);

                // Now that the device is connected, scan for Wi-Fi networks
                espDevice.scanNetworks(new WiFiScanListener() {
                    @Override
                    public void onWifiListReceived(ArrayList<com.espressif.provisioning.WiFiAccessPoint> wifiList) {
                        List<String> ssidList = new ArrayList<>();
                        for (com.espressif.provisioning.WiFiAccessPoint ap : wifiList) {
                            ssidList.add(ap.getWifiName());
                        }
                        result.success(ssidList);
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void onWiFiScanFailed(Exception e) {
                        result.error("WIFI_SCAN_FAILED", "Wi-Fi scan failed", e.getMessage());
                        espDevice.disconnectDevice();
                    }
                });
            } else if (event.getEventType() == ESPConstants.EVENT_DEVICE_DISCONNECTED) {
                EventBus.getDefault().unregister(this);
                result.error("DEVICE_DISCONNECTED", "Device disconnected", null);
            } else if (event.getEventType() == ESPConstants.EVENT_DEVICE_CONNECTION_FAILED) {
                EventBus.getDefault().unregister(this);
                result.error("CONNECTION_FAILED", "Failed to connect to device", null);
            }
        }
    };

    // Register the event subscriber
    EventBus.getDefault().register(eventSubscriber);

    // Start the connection
    espDevice.connectBLEDevice(device, serviceUuid);
}


  private void provisionWifi(String deviceName, String proofOfPossession, String ssid, String passphrase, MethodChannel.Result result) {
    BluetoothDevice device = bleDevices.get(deviceName);
    String serviceUuid = bleDeviceServiceUuids.get(deviceName);

    if (device == null || serviceUuid == null) {
        result.error("DEVICE_NOT_FOUND", "Device not found", null);
        return;
    }

    ESPDevice espDevice = espProvisionManager.createESPDevice(ESPConstants.TransportType.TRANSPORT_BLE, ESPConstants.SecurityType.SECURITY_1);

    // Create an event subscriber
    Object eventSubscriber = new Object() {
        @Subscribe(threadMode = ThreadMode.MAIN)
        public void onEvent(DeviceConnectionEvent event) {
            if (event.getEventType() == ESPConstants.EVENT_DEVICE_CONNECTED) {
                // Unregister the subscriber
                EventBus.getDefault().unregister(this);

                // Set the proof of possession
                espDevice.setProofOfPossession(proofOfPossession);

                // Now that the device is connected, proceed with provisioning
                espDevice.provision(ssid, passphrase, new ProvisionListener() {
                    @Override
                    public void createSessionFailed(Exception e) {
                        result.error("SESSION_FAILED", "Session creation failed", e.getMessage());
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void wifiConfigSent() {
                        // Wi-Fi config sent
                    }

                    @Override
                    public void wifiConfigFailed(Exception e) {
                        result.error("CONFIG_FAILED", "Wi-Fi config failed", e.getMessage());
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void wifiConfigApplied() {
                        // Wi-Fi config applied
                    }

                    @Override
                    public void wifiConfigApplyFailed(Exception e) {
                        result.error("APPLY_FAILED", "Wi-Fi config apply failed", e.getMessage());
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void provisioningFailedFromDevice(ESPConstants.ProvisionFailureReason failureReason) {
                        result.error("PROVISION_FAILED", "Provisioning failed from device", failureReason.toString());
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void deviceProvisioningSuccess() {
                        result.success(true);
                        espDevice.disconnectDevice();
                    }

                    @Override
                    public void onProvisioningFailed(Exception e) {
                        result.error("PROVISION_FAILED", "Provisioning failed", e.getMessage());
                        espDevice.disconnectDevice();
                    }
                });
            } else if (event.getEventType() == ESPConstants.EVENT_DEVICE_DISCONNECTED) {
                EventBus.getDefault().unregister(this);
                result.error("DEVICE_DISCONNECTED", "Device disconnected", null);
            } else if (event.getEventType() == ESPConstants.EVENT_DEVICE_CONNECTION_FAILED) {
                EventBus.getDefault().unregister(this);
                result.error("CONNECTION_FAILED", "Failed to connect to device", null);
            }
        }
    };

    // Register the event subscriber
    EventBus.getDefault().register(eventSubscriber);

    // Start the connection
    espDevice.connectBLEDevice(device, serviceUuid);
}


    // KBeacon Methods
    private void startKBeaconScan(MethodChannel.Result result) {
        int scanResult = kBeaconsMgr.startScanning();
        if (scanResult == 0) {
            result.success("Scan started successfully");
        } else {
            result.error("SCAN_FAILED", "Failed to start scanning", null);
        }
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

            connectedBeacon.modifyConfig(configList, new ActionCallback() {
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
                        result.error("NAME_CHANGE_FAILED", "Failed to change device name", null);
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
