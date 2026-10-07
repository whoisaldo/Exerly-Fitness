function checkDigit(body) {
  const sum = [...body]
    .reverse()
    .reduce((total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 3 : 1), 0);
  return String((10 - (sum % 10)) % 10);
}

function expandUPCE(code) {
  if (!/^[01]\d{7}$/.test(code)) return null;
  const [system, a, b, c, d, e, f, check] = code;
  let body;
  if ('012'.includes(f)) body = `${system}${a}${b}${f}0000${c}${d}${e}`;
  else if (f === '3') body = `${system}${a}${b}${c}00000${d}${e}`;
  else if (f === '4') body = `${system}${a}${b}${c}${d}00000${e}`;
  else body = `${system}${a}${b}${c}${d}${e}0000${f}`;
  return body + check;
}

function normalizeBarcode(raw, symbology) {
  if (typeof raw !== 'string' || !/^\d+$/.test(raw.trim())) {
    return {
      status: 'invalid_code',
      message: 'Enter the barcode as digits, including leading zeros.',
    };
  }
  const code = raw.trim();
  const type = String(symbology ?? '')
    .toLowerCase()
    .replace(/[-_]/g, '');
  const supported = ['', 'upca', 'upce', 'ean8', 'ean13', 'gtin14', 'itf14'];
  if (!supported.includes(type))
    return { status: 'unsupported_format', message: 'Use a UPC or EAN product barcode.' };
  if (!type && code.length === 8)
    return {
      status: 'unsupported_format',
      message: 'Choose EAN-8 or UPC-E for an eight-digit code.',
    };
  const lengths = { upca: 12, upce: 8, ean8: 8, ean13: 13, gtin14: 14, itf14: 14 };
  if ((type && code.length !== lengths[type]) || ![8, 12, 13, 14].includes(code.length)) {
    return {
      status: 'invalid_code',
      message: 'The number of digits does not match the barcode format.',
    };
  }
  const expanded = type === 'upce' ? expandUPCE(code) : code;
  if (!expanded || checkDigit(expanded.slice(0, -1)) !== expanded.at(-1)) {
    return {
      status: 'invalid_code',
      message: 'The check digit is invalid. Check the printed numbers and try again.',
    };
  }
  const gtin14 = expanded.padStart(14, '0');
  const gtin13 = gtin14[0] === '0' ? gtin14.slice(1) : null;
  const retail = gtin13?.startsWith('00000') ? gtin13.slice(5) : (gtin13 ?? gtin14);
  const aliases = [
    ...new Set(
      [
        code,
        expanded,
        gtin14,
        gtin13,
        gtin13?.startsWith('0') ? gtin13.slice(1) : null,
        retail,
      ].filter(Boolean)
    ),
  ];
  return {
    status: 'valid',
    raw: code,
    symbology: type,
    identity: gtin14,
    gtin13,
    openFoodFacts: retail,
    aliases,
  };
}

module.exports = { checkDigit, expandUPCE, normalizeBarcode };
