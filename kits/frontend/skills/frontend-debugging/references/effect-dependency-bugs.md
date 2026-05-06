# Effect Dependency Bugs

Three categories of `useEffect` dependency bugs: infinite loops, stale closures, and missing cleanup. Each with detection patterns, root causes, and fixes.

## 1. Infinite Loops

**Symptom**: Effect runs more than expected. Component re-renders infinitely. Browser tab freezes or CPU spikes.

**Detection**:
- Add `console.log('effect ran')` inside the effect — count how many times it fires
- React DevTools Profiler — repeated renders in the timeline
- Browser console shows "Maximum update depth exceeded"

**Root causes**:

### A. Missing dependency that triggers its own state change

```tsx
// PROBLEM: fetch on mount, but missing dep causes infinite re-fetch
function UserProfile({ userId }) {
  const [profile, setProfile] = useState(null);

  useEffect(() => {
    fetchProfile(userId).then(setProfile);
  }); // no dependency array — runs on EVERY render

  // setProfile causes re-render → effect runs again → fetch again → setProfile → re-render → ...
  return <div>{profile?.name}</div>;
}

// FIX: add the dependency array
function UserProfile({ userId }) {
  const [profile, setProfile] = useState(null);

  useEffect(() => {
    fetchProfile(userId).then(setProfile);
  }, [userId]); // only runs when userId changes
}
```

### B. Unstable dependencies — objects/arrays recreated each render

```tsx
// PROBLEM: inline object in dependency array changes reference every render
function SearchResults({ query }) {
  const [results, setResults] = useState([]);

  const filters = { category: 'all', sortBy: 'date' }; // new object every render

  useEffect(() => {
    search(query, filters).then(setResults);
  }, [query, filters]); // filters is a new object reference each render → infinite loop

  return <ResultList items={results} />;
}

// FIX 1: stabilize with useMemo
function SearchResults({ query }) {
  const [results, setResults] = useState([]);

  const filters = useMemo(() => ({ category: 'all', sortBy: 'date' }), []);

  useEffect(() => {
    search(query, filters).then(setResults);
  }, [query, filters]); // filters reference is stable now
}

// FIX 2: use functional setState when you only need the previous state
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(prev => prev + 1); // functional update — no dependency on count
    }, 1000);
    return () => clearInterval(id);
  }, []); // empty deps — no infinite loop
}
```

### C. Unstable callback dependency

```tsx
// PROBLEM: inline callback recreated each render
function DataGrid({ items }) {
  const [filtered, setFiltered] = useState(items);

  const applyFilter = (data) => data.filter(item => item.active); // new function each render

  useEffect(() => {
    setFiltered(applyFilter(items));
  }, [items, applyFilter]); // applyFilter is unstable → effect runs every render

  return <Grid data={filtered} />;
}

// FIX: stabilize with useCallback
function DataGrid({ items }) {
  const [filtered, setFiltered] = useState(items);

  const applyFilter = useCallback(
    (data) => data.filter(item => item.active),
    [] // stable reference
  );

  useEffect(() => {
    setFiltered(applyFilter(items));
  }, [items, applyFilter]);
}
```

## 2. Stale Closures

**Symptom**: Callback inside effect uses an outdated value. Data doesn't update when it should. Handlers reference old state.

**Detection**:
- Log the value used inside the effect callback — it may be stale
- State updates inside setTimeout/setInterval/subscription callbacks reference old values
- Click handlers bound in effects fire with wrong data

**Root cause**: Missing dependency in the effect — the callback closes over a value that changes later but the effect doesn't re-run.

```tsx
// PROBLEM: count is stale in the interval callback
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      console.log(count); // always logs 0 — stale closure
      setCount(count + 1); // always sets to 1 — stale
    }, 1000);
    return () => clearInterval(id);
  }, []); // count is NOT in deps — effect never re-runs with new count
}

// FIX 1: add missing dependency (effect re-runs each time)
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(count + 1); // uses fresh count
    }, 1000);
    return () => clearInterval(id);
  }, [count]); // re-runs when count changes — interval reset each time
}

// FIX 2: use functional setState (no dependency needed)
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(prev => prev + 1); // prev is always the latest value
    }, 1000);
    return () => clearInterval(id);
  }, []); // stable — no stale closure
}

// FIX 3: useRef for values you intentionally don't want to react to
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);
  const roomIdRef = useRef(roomId);
  roomIdRef.current = roomId; // update ref on every render

  useEffect(() => {
    const connection = createConnection(roomIdRef.current);
    connection.onMessage((msg) => setMessages(prev => [...prev, msg]));
    return () => connection.disconnect();
  }, []); // stable — connection uses ref.current which is always up to date
}
```

### Stale event listener callback

```tsx
// PROBLEM: scroll handler uses stale scrollY
function ScrollTracker() {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      // this callback is created once — any other state referenced here is stale
      setScrollY(window.scrollY);
      if (scrollY > 500) { // scrollY is stale — always 0
        sendAnalytics('deep_scroll');
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []); // scrollY not in deps
}

// FIX: use the event directly or functional setState
function ScrollTracker() {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const currentY = window.scrollY;
      setScrollY(currentY); // set from event, not from state
      if (currentY > 500) {
        sendAnalytics('deep_scroll');
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);
}
```

## 3. Missing Cleanup

**Symptom**: Memory grows over time. Events fire after component unmounts. Multiple subscriptions pile up. Intervals keep running after navigating away.

**Detection**:
- Browser DevTools Memory panel — heap size grows on repeated mount/unmount cycles
- Console messages appearing after component should be gone
- Network requests continuing after page navigation
- Multiple timer callbacks firing (check with `console.log` in the interval)

**Root cause**: No cleanup return function in the effect. Subscriptions, event listeners, timers, and connections leak.

```tsx
// PROBLEM: WebSocket connection never closed
function LiveFeed({ channel }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${channel}`);
    ws.onmessage = (event) => {
      setMessages(prev => [...prev, JSON.parse(event.data)]);
    };
    // no cleanup — WebSocket stays open after unmount
  }, [channel]);
}

// FIX: disconnect in cleanup
function LiveFeed({ channel }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${channel}`);
    ws.onmessage = (event) => {
      setMessages(prev => [...prev, JSON.parse(event.data)]);
    };
    return () => {
      ws.close(); // cleanup — close connection on unmount or channel change
    };
  }, [channel]);
}
```

### Event listener leak

```tsx
// PROBLEM: resize listener never removed
function ResponsiveLayout() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    // no cleanup — listener stacks up on every mount
  }, []);

  // After navigating away and back, you have TWO resize listeners
}

// FIX: remove listener in cleanup
function ResponsiveLayout() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => {
      window.removeEventListener('resize', checkMobile);
    };
  }, []);
}
```

### Interval leak

```tsx
// PROBLEM: polling interval keeps running after unmount
function StockPrice({ symbol }) {
  const [price, setPrice] = useState(null);

  useEffect(() => {
    const id = setInterval(() => {
      fetchPrice(symbol).then(setPrice);
    }, 5000);
    // no cleanup — interval fires even after navigating to another page
  }, [symbol]);

  return <div>{price}</div>;
}

// FIX: clear interval in cleanup
function StockPrice({ symbol }) {
  const [price, setPrice] = useState(null);

  useEffect(() => {
    const id = setInterval(() => {
      fetchPrice(symbol).then(setPrice);
    }, 5000);
    return () => clearInterval(id);
  }, [symbol]);
}
```

### AbortController for fetch cleanup

```tsx
// PROBLEM: fetch continues after unmount — setState on unmounted component
function SearchResult({ query }) {
  const [result, setResult] = useState(null);

  useEffect(() => {
    fetch(`/api/search?q=${query}`)
      .then(res => res.json())
      .then(setResult); // called after unmount — React warning or silent state leak
  }, [query]);
}

// FIX: abort fetch on cleanup
function SearchResult({ query }) {
  const [result, setResult] = useState(null);

  useEffect(() => {
    const controller = new AbortController();

    fetch(`/api/search?q=${query}`, { signal: controller.signal })
      .then(res => res.json())
      .then(setResult)
      .catch((err) => {
        if (err.name !== 'AbortError') throw err; // ignore abort, throw real errors
      });

    return () => controller.abort(); // abort fetch on unmount or query change
  }, [query]);
}
```

## Quick Reference Table

| Bug type | Detection | Root cause | Fix |
|---|---|---|---|
| Infinite loop | console.log in effect, DevTools profiler | Missing deps or unstable refs | Add deps, stabilize with useMemo/useCallback, or use functional setState |
| Stale closure | Stale data in handlers, old values logged | Missing dep in effect | Add dep, use functional setState, or useRef for intentional stale values |
| Missing cleanup | Memory growth, events after unmount, stacking listeners | No cleanup return function | Add return function: disconnect/close/remove/abort/clear |