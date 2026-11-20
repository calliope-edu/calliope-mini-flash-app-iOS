/*global
        atob, Event, nslog, uk, window
*/
//  Copyright 2019 David Park.
//  Modified by Calliope gGmbH, 2026.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// https://webbluetoothcg.github.io/web-bluetooth/ interface

(function () {
  'use strict';

  const wb = uk.co.greenparksoftware.wb;
  const wbutils = uk.co.greenparksoftware.wbutils;

  // https://webbluetoothcg.github.io/web-bluetooth/ interface
  nslog('Create BluetoothDevice');
  wb.BluetoothDevice = function (deviceJSON) {
    wbutils.EventTarget.call(this);

    let roProps = {
      adData: {},
      deviceClass: deviceJSON.deviceClass || 0,
      id: deviceJSON.id,
      gatt: new wb.BluetoothRemoteGATTServer(this),
      productId: deviceJSON.productId || 0,
      productVersion: deviceJSON.productVersion || 0,
      uuids: deviceJSON.uuids,
      vendorId: deviceJSON.vendorId || 0,
      vendorIdSource: deviceJSON.vendorIdSource || 'bluetooth'
    };
    wbutils.defineROProperties(this, roProps);

    this.name = deviceJSON.name;
    
    // No adData is passed by the webview. Could be added if there is any relevance.
    if (deviceJSON.adData) {
      this.adData.appearance = deviceJSON.adData.appearance || '';
      this.adData.txPower = deviceJSON.adData.txPower || 0;
      this.adData.rssi = deviceJSON.adData.rssi || 0;
      this.adData.manufacturerData = deviceJSON.adData.manufacturerData || [];
      this.adData.serviceData = deviceJSON.adData.serviceData || [];
    }
  };

  wb.BluetoothDevice.prototype = {
    toString: function () {
      return `BluetoothDevice(${this.id.slice(0, 10)})`;
    },
    handleSpontaneousDisconnectEvent: function () {
      // Code references as per
      // https://webbluetoothcg.github.io/web-bluetooth/#disconnection-events
      // 1. not implemented
      // 2.
      if (!this.gatt.connected) {
        return;
      }
      // 3.1
      this.gatt.connected = false;
      // 3.2-3.7 not implemented
      // 3.8
      this.dispatchEvent(new wb.BluetoothEvent('gattserverdisconnected', this));
    }
  };
  wbutils.mixin(wb.BluetoothDevice, wbutils.EventTarget);
})();
