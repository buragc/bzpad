import { useEffect, useState } from 'react';
import { QuickAdd } from './QuickAdd';

export function GlobalQuickAdd() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && (e.key === 'n' || e.key === 'N')) {
        // Only if not in an input
        const target = e.target as HTMLElement;
        if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') return;
        e.preventDefault();
        setOpen(o => !o);
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/30 dark:bg-black/50 backdrop-blur-sm"
      onClick={e => { if (e.target === e.currentTarget) setOpen(false); }}
    >
      <div className="w-full max-w-lg mx-4 bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 p-4">
        <h3 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-3">
          Quick Add Task
        </h3>
        <QuickAdd
          autoFocus
          onDone={() => setOpen(false)}
          placeholder='Add task… e.g. "Review PR due tomorrow #work"'
        />
        <p className="text-xs text-gray-400 dark:text-gray-500 mt-2">
          Press Enter to add · Escape to cancel · Supports natural language dates and #tags
        </p>
      </div>
    </div>
  );
}
