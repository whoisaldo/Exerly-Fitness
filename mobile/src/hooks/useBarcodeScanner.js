import { useState, useCallback } from 'react';
import {
  fetchProductByBarcode,
  ProductNotFoundError,
} from '../services/OpenFoodFactsService';

/**
 * Hook for barcode scanning and product lookup.
 * @returns {{ scanning: boolean, product: object|null, error: string|null, scan: (code: string) => Promise<void>, reset: () => void }}
 */
export default function useBarcodeScanner() {
  const [scanning, setScanning] = useState(false);
  const [product, setProduct] = useState(null);
  const [error, setError] = useState(null);

  const scan = useCallback(async (barcode) => {
    setScanning(true);
    setError(null);
    setProduct(null);
    try {
      const result = await fetchProductByBarcode(barcode);
      setProduct(result);
    } catch (err) {
      if (err instanceof ProductNotFoundError) {
        setError('Product not found. Try manual entry.');
      } else {
        setError('Failed to scan. Please try again.');
      }
    } finally {
      setScanning(false);
    }
  }, []);

  const reset = useCallback(() => {
    setScanning(false);
    setProduct(null);
    setError(null);
  }, []);

  return { scanning, product, error, scan, reset };
}
