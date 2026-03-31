/**
 * Format a calorie number with comma separators.
 * @param {number} n
 * @returns {string}
 */
export function formatCalories(n) {
  if (n == null) return '0 cal';
  return `${Number(n).toLocaleString('en-US')} cal`;
}

/**
 * Format weight with unit label.
 * @param {number} n
 * @param {'lbs'|'kg'} unit
 * @returns {string}
 */
export function formatWeight(n, unit = 'lbs') {
  if (n == null) return `-- ${unit}`;
  return `${Math.round(n)} ${unit}`;
}

/**
 * Format a macro value with "g" suffix.
 * @param {number} n
 * @returns {string}
 */
export function formatMacro(n) {
  if (n == null) return '0g';
  return `${Math.round(n)}g`;
}
