// Barcode decode worker.
//
// Runs ZXing-C++ (compiled to WebAssembly) off the main thread, so decoding
// never competes with Flutter's renderer. This is the fallback tier for
// browsers without the native BarcodeDetector API — most importantly every
// browser on iOS, since WebKit does not implement Shape Detection.
//
// Both `zxing_reader.js` and `zxing_reader.wasm` are served from our own
// origin; nothing is fetched from a CDN at runtime.

importScripts('zxing_reader.js');

const { prepareZXingModule, readBarcodesFromImageData } = ZXingWASM;

// Without this the module would try to fetch the .wasm from jsDelivr.
prepareZXingModule({
  overrides: {
    locateFile: (path, prefix) =>
      path.endsWith('.wasm')
        ? new URL('zxing_reader.wasm', self.location.href).href
        : prefix + path,
  },
  fireImmediately: true,
});

// 1D symbologies only, matching BarcodeScanProfile.stockEntry1dFormats. Hang
// tags often carry a 2D code beside the product barcode, and we must not
// return that one.
const READER_OPTIONS = {
  formats: [
    'Code128',
    'Code39',
    'Code93',
    'Codabar',
    'EAN-13',
    'EAN-8',
    'ITF',
    'UPC-A',
    'UPC-E',
  ],
  // The knobs mobile_scanner's zxing-js path leaves off. tryHarder is the
  // important one: without it ZXing samples only a handful of scanlines and
  // misses barcodes on creased or slightly rotated tags.
  tryHarder: true,
  tryRotate: true,
  tryInvert: true,
  tryDownscale: true,
  maxNumberOfSymbols: 4,
};

self.onmessage = async (event) => {
  const { id, buffer, width, height } = event.data;

  try {
    const imageData = new ImageData(
      new Uint8ClampedArray(buffer),
      width,
      height,
    );
    const results = await readBarcodesFromImageData(imageData, READER_OPTIONS);

    self.postMessage({
      id,
      results: (results || [])
        .filter((result) => result && result.isValid !== false)
        .map((result) => ({
          text: String(result.text || ''),
          format: String(result.format || ''),
        }))
        .filter((result) => result.text.length > 0),
    });
  } catch (error) {
    // A decode failure is normal — most frames contain no barcode.
    self.postMessage({ id, results: [], error: String(error) });
  }
};
