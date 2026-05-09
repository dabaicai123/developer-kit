# Effect Dependency Bugs Playbook

Three categories of useEffect dependency bugs: infinite loops, stale closures, and missing cleanup. Detection patterns, root causes, and fixes.

## Bug Category 1: Infinite Loops

**What happens**: The effect runs repeatedly, causing the component to re-render infinitely. The browser tab may freeze, or React throws "Maximum update depth exceeded."

### Detection

- **Console log in effect**: Add `console.log('effect ran', count++)` — if count climbs rapidly, you have an infinite loop
- **React DevTools Profiler**: Repeated renders in the timeline for the same component
- **Browser freeze**: Tab becomes unresponsive, high CPU usage
- **React error**: "Maximum update depth exceeded" in console

### Root causes and fixes

#### Root cause A: Unstable dependency — inline object/array recreated each render

```tsx
// BUG: filters is a new object every render → effect re-runs → setResults → re-render → new filters → effect re-runs...
function SearchResults({ query }) {
  const [results, setResults] = useState([]);

  const filters = { category: 'all', sortBy: 'date' }; // new reference each render

  useEffect(() => {
    search(query, filters).then(setResults);
  }, [query, filters]); // filters reference changes every render → infinite loop

  return <ResultList items={results} />;
}

// FIX: stabilize with useMemo
function SearchResults({ query }) {
  const [results, setResults] = useState([]);

  const filters = useMemo(() => ({ category: 'all', sortBy: 'date' }), []); // stable reference

  useEffect(() => {
    search(query, filters).then(setResults);
  }, [query, filters]); // filters stable now — effect runs only when query changes
}
```

#### Root cause B: Unstable callback dependency

```tsx
// BUG: applyFilter is a new function every render → effect re-runs
function DataGrid({ items }) {
  const [filtered, setFiltered] = useState(items);

  const applyFilter = (data) => data.filter(item => item.active); // new function each render

  useEffect(() => {
    setFiltered(applyFilter(items));
  }, [items, applyFilter]); // applyFilter unstable → infinite loop

  return <Grid data={filtered} />;
}

// FIX: stabilize with useCallback
function DataGrid({ items }) {
  const [filtered, setFiltered] = useState(items);

  const applyFilter = useCallback(
    (data) => data.filter(item => item.active),
    []
  );

  useEffect(() => {
    setFiltered(applyFilter(items));
  }, [items, applyFilter]); // applyFilter stable
}
```

#### Root cause C: State setter called inside effect with no dependency array

```tsx
// BUG: no dependency array → effect runs on every render
function UserProfile({ userId }) {
  const [profile, setProfile] = useState(null);

  useEffect(() => {
    fetchProfile(userId).then(setProfile);
  }); // missing dependency array — runs every render

  return <div>{profile?.name}</div>;
}

// FIX: add dependency array
function UserProfile({ userId }) {
  const [profile, setProfile] = useState(null);

  useEffect(() => {
    fetchProfile(userId).then(setProfile);
  }, [userId]); // runs only when userId changes
}
```

#### Root cause D: setState triggering the same effect dependency

```tsx
// BUG: effect sets count, which is a dependency, causing re-run
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    setCount(count + 1); // count changes → effect re-runs → count changes → infinite loop
  }, [count]);

  return <div>{count}</div>;
}

// FIX: use functional setState — doesn't need count as dependency
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(prev => prev + 1); // functional update — doesn't reference count
    }, 1000);
    return () => clearInterval(id);
  }, []); // no dependency on count — stable
}
```

## Bug Category 2: Stale Closures

**What happens**: A callback inside the effect references a value from the render when the effect was created, not the current render. The callback uses an outdated value.

### Detection

- **Stale data in handlers**: Event handler or interval callback uses an old value instead of the current one
- **Console log mismatch**: Log the value inside the effect callback — it may show an old value
- **Feature bug**: Submit button sends old form data, timer shows wrong count, scroll handler reads old scroll position

### Root causes and fixes

#### Root cause A: Missing dependency — effect doesn't re-run when value changes

```tsx
// BUG: count is stale — effect created once, count stays at 0
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      console.log(count); // always 0 — stale closure
      setCount(count + 1); // always sets to 1 — stale
    }, 1000);
    return () => clearInterval(id);
  }, []); // count not in deps — callback captures count=0 from first render
}

// FIX 1: add missing dependency (effect re-runs, interval resets)
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(count + 1); // uses fresh count from this render
    }, 1000);
    return () => clearInterval(id);
  }, [count]); // re-creates interval each time count changes
}

// FIX 2: functional setState (preferred — no dependency needed)
function Timer() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setCount(prev => prev + 1); // prev is always latest
    }, 1000);
    return () => clearInterval(id);
  }, []); // stable — no stale closure risk
}
```

#### Root cause B: useRef for values you intentionally don't want to react to

Sometimes you need the latest value in a callback but don't want the effect to re-run. Use a ref to track the current value.

```tsx
// BUG: roomId is stale in WebSocket connection
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${roomId}`);
    ws.onMessage = (msg) => setMessages(prev => [...prev, JSON.parse(msg)]);
    return () => ws.close();
  }, []); // roomId not in deps — connection always uses initial roomId
}

// FIX: useRef to track current roomId without triggering effect re-run
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);
  const roomIdRef = useRef(roomId);
  roomIdRef.current = roomId; // update ref on every render

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${roomIdRef.current}`);
    ws.onMessage = (msg) => setMessages(prev => [...prev, JSON.parse(msg)]);
    return () => ws.close();
  }, []); // effect runs once — roomIdRef.current always has latest roomId
}
```

Note: Only use this pattern when you intentionally want the effect to run once. If you need to reconnect when roomId changes, add roomId to the dependency array and let the effect re-run (with cleanup creating a new connection).

#### Root cause C: Stale event listener callback

```tsx
// BUG: scroll handler uses stale state
function ScrollTracker() {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      setScrollY(window.scrollY);
      if (scrollY > 500) { // scrollY is stale — always 0 from first render
        sendAnalytics('deep_scroll');
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []); // scrollY not in deps
}

// FIX: derive logic from the event, not from stale state
function ScrollTracker() {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const currentY = window.scrollY;
      setScrollY(currentY);
      if (currentY > 500) { // use event value, not state
        sendAnalytics('deep_scroll');
      }
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);
}
```

## Bug Category 3: Missing Cleanup

**What happens**: Subscriptions, event listeners, timers, or connections continue running after the component unmounts. Memory leaks grow over time. Events fire when they shouldn't.

### Detection

- **Memory growth**: DevTools Memory panel — heap grows on repeated mount/unmount cycles
- **Events after unmount**: Console messages from subscriptions/intervals appearing after navigating away
- **Stacking listeners**: Multiple callbacks firing for the same event (check with `console.log` in the handler)
- **Network requests after unmount**: Fetch calls continuing in the Network tab after leaving the page

### Root causes and fixes

#### Root cause A: No cleanup return function

```tsx
// BUG: resize listener stacks up on every mount/unmount cycle
function ResponsiveLayout() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    // no cleanup — listener stacks up
  }, []);
  // After 3 mount/unmount cycles, you have 3 resize listeners
}

// FIX: remove listener in cleanup
function ResponsiveLayout() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile); // cleanup
  }, []);
}
```

#### Root cause B: Interval/timer not cleared

```tsx
// BUG: polling interval keeps running after unmount
function StockPrice({ symbol }) {
  const [price, setPrice] = useState(null);

  useEffect(() => {
    const id = setInterval(() => {
      fetchPrice(symbol).then(setPrice); // continues after navigating away
    }, 5000);
    // no cleanup — interval fires every 5s even after unmount
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
    return () => clearInterval(id); // cleanup
  }, [symbol]);
}
```

#### Root cause C: WebSocket/connection not closed

```tsx
// BUG: WebSocket stays open after component unmounts
function LiveFeed({ channel }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${channel}`);
    ws.onmessage = (event) => {
      setMessages(prev => [...prev, JSON.parse(event.data)]);
    };
    // no cleanup — connection leaks
  }, [channel]);
}

// FIX: close connection in cleanup
function LiveFeed({ channel }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${channel}`);
    ws.onmessage = (event) => {
      setMessages(prev => [...prev, JSON.parse(event.data)]);
    };
    return () => ws.close(); // cleanup
  }, [channel]);
}
```

#### Root cause D: Fetch not aborted on unmount

```tsx
// BUG: fetch continues after unmount — setState called on unmounted component
function SearchResult({ query }) {
  const [result, setResult] = useState(null);

  useEffect(() => {
    fetch(`/api/search?q=${query}`)
      .then(res => res.json())
      .then(setResult); // called after unmount
  }, [query]);
}

// FIX: abort fetch in cleanup
function SearchResult({ query }) {
  const [result, setResult] = useState(null);

  useEffect(() => {
    const controller = new AbortController();

    fetch(`/api/search?q=${query}`, { signal: controller.signal })
      .then(res => res.json())
      .then(setResult)
      .catch(err => {
        if (err.name !== 'AbortError') throw err; // ignore abort, throw real errors
      });

    return () => controller.abort(); // cleanup — abort pending fetch
  }, [query]);
}
```

#### Root cause E: Multiple subscriptions stacking

```tsx
// BUG: effect re-runs on channel change but old subscription isn't cleaned up
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${roomId}`);
    ws.onmessage = (e) => setMessages(prev => [...prev, JSON.parse(e.data)]);
    // when roomId changes, a NEW WebSocket is created but the OLD one stays open
    // after 3 room changes, you have 3 active connections receiving messages
  }, [roomId]);
}

// FIX: cleanup previous subscription before creating new one
function ChatRoom({ roomId }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/${roomId}`);
    ws.onmessage = (e) => setMessages(prev => [...prev, JSON.parse(e.data)]);
    return () => ws.close(); // cleanup — close old connection before new one opens
  }, [roomId]);
}
```

## Quick Reference Table

| Bug type | Detection method | Root cause | Fix pattern |
|---|---|---|---|
| Infinite loop | console.log in effect, DevTools profiler | Unstable dep (inline object, new function each render) | useMemo/useCallback to stabilize, or functional setState |
| Infinite loop | "Maximum update depth exceeded" | setState in effect triggers same dep | Functional setState or restructure effect deps |
| Infinite loop | Effect runs every render | Missing dependency array | Add `[dep]` dependency array |
| Stale closure | Handler uses old value | Missing dep in effect | Add dep, or use functional setState |
| Stale closure | Callback ignores latest state | Effect created once, doesn't re-run | useRef to track latest value without triggering re-run |
| Stale closure | Event listener reads stale state | State not in deps, event uses old state | Derive from event data, not stale state |
| Missing cleanup | Memory growth on mount/unmount | No cleanup return function | Add `return () => { cleanup }` |
| Missing cleanup | Events fire after unmount | Listener/subscription not removed | `removeEventListener` / `unsubscribe` / `ws.close()` in cleanup |
| Missing cleanup | Fetch after unmount | No AbortController | `controller.abort()` in cleanup |
| Missing cleanup | Stacking subscriptions | Old subscription not closed on dep change | Cleanup function closes previous before new opens |