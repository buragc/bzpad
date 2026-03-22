import { useTaskStore } from '../store/useTaskStore';
import type { Quadrant } from '../types';
import { QUADRANT_CONFIG } from '../types';

export function SearchBar() {
  const { filter, setFilter, getAllTags } = useTaskStore();
  const allTags = getAllTags();

  function toggleQuadrant(q: Quadrant) {
    const current = filter.quadrants;
    const next = current.includes(q) ? current.filter(x => x !== q) : [...current, q];
    setFilter({ quadrants: next });
  }

  function toggleTag(tag: string) {
    const current = filter.tags;
    const next = current.includes(tag) ? current.filter(t => t !== tag) : [...current, tag];
    setFilter({ tags: next });
  }

  const hasFilter = filter.search || filter.quadrants.length > 0 || filter.tags.length > 0;

  return (
    <div className="flex items-center gap-2 flex-wrap">
      {/* Search input */}
      <div className="relative flex-1 min-w-[200px]">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          value={filter.search}
          onChange={e => setFilter({ search: e.target.value })}
          placeholder="Search tasks…"
          className="w-full pl-9 pr-3 py-1.5 text-sm bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:border-blue-400 dark:focus:border-blue-500 transition-colors"
        />
        {filter.search && (
          <button
            onClick={() => setFilter({ search: '' })}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>

      {/* Quadrant filters */}
      {([1, 2, 3, 4] as Quadrant[]).map(q => {
        const active = filter.quadrants.includes(q);
        const colors = ['bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300', 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300', 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300', 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300'];
        return (
          <button
            key={q}
            onClick={() => toggleQuadrant(q)}
            className={`text-xs px-2.5 py-1 rounded-full font-medium transition-all ${active ? colors[q - 1] + ' ring-2 ring-offset-1 ring-current' : 'text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'}`}
            title={QUADRANT_CONFIG[q].label}
          >
            Q{q}
          </button>
        );
      })}

      {/* Tag filters */}
      {allTags.slice(0, 5).map(tag => (
        <button
          key={tag}
          onClick={() => toggleTag(tag)}
          className={`text-xs px-2.5 py-1 rounded-full transition-all ${filter.tags.includes(tag) ? 'bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-300 ring-2 ring-offset-1 ring-purple-400' : 'bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'}`}
        >
          #{tag}
        </button>
      ))}

      {/* Clear filters */}
      {hasFilter && (
        <button
          onClick={() => setFilter({ search: '', quadrants: [], tags: [] })}
          className="text-xs text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 underline transition-colors"
        >
          Clear
        </button>
      )}
    </div>
  );
}
