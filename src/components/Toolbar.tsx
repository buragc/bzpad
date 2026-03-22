import { useTaskStore } from '../store/useTaskStore';
import { SearchBar } from './SearchBar';

export function Toolbar() {
  const { viewMode, setViewMode, darkMode, setDarkMode, getArchivedTasks, undo } = useTaskStore();
  const archivedCount = getArchivedTasks().length;

  const nextDarkMode = darkMode === 'system' ? 'light' : darkMode === 'light' ? 'dark' : 'system';
  const darkModeLabel = { system: '🌓', light: '☀️', dark: '🌙' }[darkMode];

  return (
    <div className="flex items-center gap-3 px-6 py-3 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 shrink-0">
      {/* Logo */}
      <div className="flex items-center gap-2 shrink-0 mr-2">
        <div className="w-7 h-7 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
          <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 5h7M4 12h7M4 19h7M13 5h7M13 12h7M13 19h7" />
          </svg>
        </div>
        <span className="font-bold text-sm text-gray-900 dark:text-gray-100 hidden sm:block">BzPad</span>
      </div>

      {/* Search & Filters (only in matrix view) */}
      {viewMode === 'matrix' && (
        <div className="flex-1 min-w-0">
          <SearchBar />
        </div>
      )}

      {viewMode === 'archive' && (
        <div className="flex-1" />
      )}

      {/* View toggle */}
      <div className="flex items-center gap-1 bg-gray-100 dark:bg-gray-800 rounded-lg p-1 shrink-0">
        <button
          onClick={() => setViewMode('matrix')}
          className={`px-3 py-1 rounded-md text-xs font-medium transition-all ${viewMode === 'matrix' ? 'bg-white dark:bg-gray-700 shadow text-gray-900 dark:text-gray-100' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}`}
        >
          Matrix
        </button>
        <button
          onClick={() => setViewMode('archive')}
          className={`px-3 py-1 rounded-md text-xs font-medium transition-all flex items-center gap-1 ${viewMode === 'archive' ? 'bg-white dark:bg-gray-700 shadow text-gray-900 dark:text-gray-100' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'}`}
        >
          Archive
          {archivedCount > 0 && (
            <span className="bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 text-xs px-1.5 rounded-full">{archivedCount}</span>
          )}
        </button>
      </div>

      {/* Undo */}
      <button
        onClick={undo}
        title="Undo (Ctrl+Z)"
        className="p-1.5 rounded-lg text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 transition-colors shrink-0"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
        </svg>
      </button>

      {/* Dark mode toggle */}
      <button
        onClick={() => setDarkMode(nextDarkMode)}
        title={`Theme: ${darkMode}`}
        className="p-1.5 rounded-lg text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 transition-colors shrink-0 text-base"
      >
        {darkModeLabel}
      </button>
    </div>
  );
}
