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

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (!query || query.length < 2) {
      setResults([]);
      setError(null);
      setPage(1);
      setHasMore(false);
      return;
    }

    debounceRef.current = setTimeout(async () => {
      currentQuery.current = query;
      setLoading(true);
      setError(null);

      try {
        const data = await searchFoods(query, 1);
        if (currentQuery.current !== query) return;
        setResults(data.products);
        setPage(1);
        setHasMore(data.total > 25);
      } catch (err) {
        if (currentQuery.current !== query) return;
        setError(err.message ?? 'Search failed');
        setResults([]);
      } finally {
        if (currentQuery.current === query) {
          setLoading(false);
        }
      }
    }, 400);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  const loadMore = useCallback(async () => {
    if (!hasMore || loading) return;
    const nextPage = page + 1;
    setLoading(true);

    try {
      const data = await searchFoods(currentQuery.current, nextPage);
      setResults((prev) => {
        const ids = new Set(prev.map((p) => p.id));
        const newItems = data.products.filter((p) => !ids.has(p.id));
        return [...prev, ...newItems];
      });
      setPage(nextPage);
      setHasMore(data.total > nextPage * 25);
    } catch {
      // keep existing results
    } finally {
      setLoading(false);
    }
  }, [hasMore, loading, page]);

  const reset = useCallback(() => {
    setQuery('');
    setResults([]);
    setError(null);
    setPage(1);
    setHasMore(false);
    currentQuery.current = '';
  }, []);

  return { query, setQuery, results, loading, error, loadMore, hasMore, reset };
}
