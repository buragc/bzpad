import { useEffect } from 'react';
import { useTaskStore } from './store/useTaskStore';
import { Toolbar } from './components/Toolbar';
import { Matrix } from './components/Matrix';
import { ArchiveView } from './components/ArchiveView';
import { GlobalQuickAdd } from './components/GlobalQuickAdd';
import { QuickAdd } from './components/QuickAdd';
import './index.css';

function App() {
  const { viewMode, darkMode } = useTaskStore();

  // Apply dark mode class
  useEffect(() => {
    const root = document.documentElement;
    const apply = (dark: boolean) => {
      if (dark) root.classList.add('dark');
      else root.classList.remove('dark');
    };

    if (darkMode === 'dark') {
      apply(true);
    } else if (darkMode === 'light') {
      apply(false);
    } else {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      apply(mq.matches);
      const handler = (e: MediaQueryListEvent) => apply(e.matches);
      mq.addEventListener('change', handler);
      return () => mq.removeEventListener('change', handler);
    }
  }, [darkMode]);

  return (
    <div className="flex flex-col h-screen bg-gray-100 dark:bg-gray-950 overflow-hidden">
      <Toolbar />

      {viewMode === 'matrix' ? (
        <div className="flex-1 flex flex-col min-h-0 p-4 gap-4 overflow-hidden">
          <QuickAdd placeholder='Add task… supports "due tomorrow", urgent keywords, #tags · Ctrl+N for modal' />
          <div className="flex-1 min-h-0">
            <Matrix />
          </div>
        </div>
      ) : (
        <div className="flex-1 min-h-0 overflow-hidden">
          <ArchiveView />
        </div>
      )}

      <GlobalQuickAdd />
    </div>
  );
}

export default App;
