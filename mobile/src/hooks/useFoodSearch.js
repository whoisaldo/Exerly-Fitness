import { useState, useCallback, useRef, useEffect } from 'react';
import { searchFoods } from '../services/OpenFoodFactsService';

export default function useFoodSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);

  const debounceRef = useRef(null);
  const currentQuery = useRef('');
  const requestIdRef = useRef(0);

  const runSearch = useCallback(async (nextQuery, nextPage = 1, mode = 'replace') => {
    const requestId = ++requestIdRef.current;

    currentQuery.current = nextQuery;
    setLoading(true);
    setError(null);

    try {
      const data = await searchFoods(nextQuery, nextPage);
      if (requestId !== requestIdRef.current) return;

      if (mode === 'append') {
        setResults((prev) => {
          const ids = new Set(prev.map((p) => p.id));
          const newItems = data.products.filter((p) => !ids.has(p.id));
          return [...prev, ...newItems];
        });
      } else {
        setResults(data.products);
      }

      setPage(nextPage);
      setHasMore(data.total > nextPage * 25);
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      if (mode !== 'append') {
        setResults([]);
      }
      setError(err.message ?? 'Search failed');
    } finally {
      if (requestId === requestIdRef.current) {
        setLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (!query || query.length < 2) {
      requestIdRef.current += 1;
      setResults([]);
      setError(null);
      setPage(1);
      setHasMore(false);
      setLoading(false);
      currentQuery.current = '';
      return;
    }

    debounceRef.current = setTimeout(async () => {
      runSearch(query, 1, 'replace');
    }, 400);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query, runSearch]);

  const loadMore = useCallback(async () => {
    if (!hasMore || loading) return;
    const nextPage = page + 1;
    runSearch(currentQuery.current, nextPage, 'append');
  }, [hasMore, loading, page, runSearch]);

  const retry = useCallback(() => {
    const activeQuery = currentQuery.current || query;
    if (!activeQuery || activeQuery.length < 2) return;
    runSearch(activeQuery, 1, 'replace');
  }, [query, runSearch]);

  const reset = useCallback(() => {
    requestIdRef.current += 1;
    setQuery('');
    setResults([]);
    setError(null);
    setPage(1);
    setHasMore(false);
    setLoading(false);
    currentQuery.current = '';
  }, []);

  return { query, setQuery, results, loading, error, loadMore, hasMore, reset, retry };
}
