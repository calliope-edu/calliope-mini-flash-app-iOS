/*jslint
        browser
*/
/*global
        atob, Event, TextEncoder, uk, window
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
eval('var uk = uk || {};');
if (!uk.co) {
  uk.co = {};
}
if (!uk.co.greenparksoftware) {
  uk.co.greenparksoftware = {};
}
uk.co.greenparksoftware.wb = {};
uk.co.greenparksoftware.wbutils = {
  uint8ArrayToBase64: function (bytes) {
    let binary = '';
    bytes.forEach(function (byte) {
      const char = String.fromCharCode(byte);
      binary += char;
    });
    let b64 = window.btoa(binary);
    return b64;
  },
  btDeviceNameIsOk: function (name) {
    'use strict';
    let nameUTF8len = new TextEncoder().encode(name).byteLength;
    return nameUTF8len <= 248 && nameUTF8len >= 0;
  },
  canonicaliseFilter: function (filter) {
    'use strict';
    // implemented as far as possible as per
    // https://webbluetoothcg.github.io/web-bluetooth/#bluetoothlescanfilterinit-canonicalizing
    const services = filter.services;
    const name = filter.name;
    const wbutils = uk.co.greenparksoftware.wbutils;
    if (name !== undefined && !wbutils.btDeviceNameIsOk(name)) {
      throw new TypeError(`Invalid filter name ${name}`);
    }
    const namePrefix = filter.namePrefix;
    if (
      namePrefix !== undefined && (
        !wbutils.btDeviceNameIsOk(namePrefix) ||
        new TextEncoder().encode(namePrefix).byteLength === 0
      )
    ) {
      throw new TypeError(`Invalid filter namePrefix ${namePrefix}`);
    }

    let canonicalizedFilter = { name, namePrefix };

    if (services === undefined && name === undefined && namePrefix === undefined) {
      throw new TypeError('Filter has no usable properties');
    }
    if (services !== undefined) {
      if (!services) {
        throw new TypeError('Filter has empty services');
      }
      let cservs = services.map(window.BluetoothUUID.getService);
      canonicalizedFilter.services = cservs;
    }

    return canonicalizedFilter;
  },
  defineROProperties: function (target, roDescriptors) {
    Object.keys(roDescriptors).forEach(function (key) {
      Object.defineProperty(target, key, {value: roDescriptors[key]});
    });
  },
  mixin: function (target, src) {
    Object.assign(target.prototype, src.prototype);
    target.prototype.constructor = target;
  },
  str64todv: function (str64) {
    // Return a DataView from a base64 encoded DOM String.
    let str16 = atob(str64);
    let ab = new Int8Array(str16.length);
    let ii;
    for (ii = 0; ii < ab.length; ii += 1) {
      // trusted interface, so don't check this is 0 <= charCode < 256
      ab[ii] = str16.charCodeAt(ii);
    }
    return new DataView(ab.buffer);
  }
};


(function () {
  let levelHandlers = {
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
  function consoleLog(level, message, ...args) {
    window.webkit.messageHandlers.logger.postMessage({level, message: `${message}`});
    if (levelHandlers[level]) {
        levelHandlers[level].call(window.console, message, ...args);
    }
  }
  window.console = {
    debug: (...args) => consoleLog('debug', ...args),
    info: (...args) => consoleLog('log', ...args),
    log: (...args) => consoleLog('log', ...args),
    warn: (...args) => consoleLog('warn', ...args),
    error: (...args) => consoleLog('error', ...args),
    dir: (...args) => consoleLog('log', ...args),
  };
  window.addEventListener('error', function (event) {
    consoleLog('error', `Uncaught error on ${event.filename || "<no filename>"}:${event.lineno || "<no lineno>"} – "${event.message}" ${event.error}`);
  });
})();

(function () {
  function nslog(message) {
    // nslog is called in the various JS polyfills
    // console.log(message);
  }
  window.nslog = nslog;
})();
window.nslog('WBUtils imported');
