import { useTaskStore } from '../store/useTaskStore';
import type { Quadrant } from '../types';
import { QUADRANT_CONFIG } from '../types';

export function BulkActions() {
  const { selectedIds, moveTasks, deleteTasks, archiveTasks, clearSelection } = useTaskStore();
  const count = selectedIds.size;

  if (count === 0) return null;

  const ids = [...selectedIds];

  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 bg-gray-900 dark:bg-gray-800 text-white px-4 py-2.5 rounded-full shadow-2xl border border-gray-700 text-sm">
      <span className="font-medium text-gray-300 mr-1">{count} selected</span>

      <span className="text-gray-600">|</span>

      <span className="text-gray-400 text-xs">Move to:</span>
      {([1, 2, 3, 4] as Quadrant[]).map(q => (
        <button
          key={q}
          onClick={() => moveTasks(ids, q)}
          title={QUADRANT_CONFIG[q].label}
          className="w-6 h-6 rounded-full text-xs font-bold transition-colors hover:scale-110"
          style={{
            backgroundColor: ['#ef4444', '#3b82f6', '#f59e0b', '#6b7280'][q - 1],
          }}
        >
          {q}
        </button>
      ))}

      <span className="text-gray-600">|</span>

      <button
        onClick={() => archiveTasks(ids)}
        className="text-gray-300 hover:text-white transition-colors flex items-center gap-1"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
        </svg>
        Archive
      </button>

      <button
        onClick={() => deleteTasks(ids)}
        className="text-red-400 hover:text-red-300 transition-colors flex items-center gap-1"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
        </svg>
        Delete
      </button>

      <button
        onClick={clearSelection}
        className="text-gray-500 hover:text-gray-300 transition-colors ml-1"
        aria-label="Clear selection"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}
